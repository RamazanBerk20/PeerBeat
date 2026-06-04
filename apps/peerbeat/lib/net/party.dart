import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../playback/player.dart';
import '../src/rust/api/network.dart';
import '../src/rust/db/tracks.dart';
import 'tofu.dart';

/// Drives synchronized party mode on both ends.
///
/// **Host:** broadcasts the local player's state (track id + position + play
/// state) to connected peers; this does not affect the host's own playback.
/// **Peer:** connects to a host's `/v1/party` WebSocket, clock-syncs (Cristian),
/// and follows — playing the host's current track (streamed) and hard-seeking
/// only when it drifts past ~100 ms.
///
/// Experimental: needs verification across two devices.
class PartyController extends ChangeNotifier {
  // ── Host side ──────────────────────────────────────────────────────────────
  bool _hosting = false;
  bool get hosting => _hosting;
  Timer? _hostTick;
  int _lastTrackId = -1;
  bool _lastPlaying = false;

  Future<void> startHosting() async {
    if (_hosting) return;
    if (!await netPartyStart()) return; // not hosting the LAN server
    _hosting = true;
    player.addListener(_onHostChange);
    _hostTick = Timer.periodic(const Duration(seconds: 3), (_) => _broadcast());
    unawaited(_broadcast());
    notifyListeners();
  }

  void _onHostChange() {
    final id = player.current?.id ?? -1;
    if (id != _lastTrackId || player.playing != _lastPlaying) {
      unawaited(_broadcast());
    }
  }

  Future<void> _broadcast() async {
    final t = player.current;
    if (t == null) return;
    _lastTrackId = t.id;
    _lastPlaying = player.playing;
    try {
      await netPartyUpdate(
        trackKey: '${t.id}',
        positionMs: player.position.inMilliseconds,
        playing: player.playing,
      );
    } catch (_) {}
  }

  Future<void> stopHosting() async {
    if (!_hosting) return;
    _hosting = false;
    _hostTick?.cancel();
    _hostTick = null;
    player.removeListener(_onHostChange);
    try {
      await netPartyStop();
    } catch (_) {}
    notifyListeners();
  }

  // ── Peer side ──────────────────────────────────────────────────────────────
  WebSocket? _ws;
  bool _joined = false;
  bool get joined => _joined;
  String _hostName = '';
  String get hostName => _hostName;
  String? _base;
  String? _token;
  int _offset = 0;
  int _bestRtt = 1 << 30;
  String _curKey = '';
  Timer? _peerTick;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Join a host's party. `base`/`token` come from the normal "open host" flow
  /// (authenticate to the whole library, then join).
  Future<void> joinParty(String base, String token, String hostName) async {
    await leaveParty();
    _base = base;
    _token = token;
    _hostName = hostName;
    _offset = 0;
    _bestRtt = 1 << 30;
    _curKey = '';
    final wsUrl = '${base.replaceFirst('https://', 'wss://')}/v1/party';
    final client = await tofuStreamClient();
    try {
      _ws = await WebSocket.connect(wsUrl, customClient: client);
    } catch (e) {
      client.close();
      rethrow;
    }
    _joined = true;
    _ws!.listen(
      _onMessage,
      onDone: () => unawaited(leaveParty()),
      onError: (_) => unawaited(leaveParty()),
      cancelOnError: true,
    );
    // Prime the clock estimate with a burst of pings, then keep it fresh.
    for (var i = 0; i < 5; i++) {
      _sendPing();
      await Future.delayed(const Duration(milliseconds: 120));
    }
    _peerTick = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendPing();
      _correctDrift();
    });
    notifyListeners();
  }

  Future<void> leaveParty() async {
    if (!_joined && _ws == null) return;
    _joined = false;
    _peerTick?.cancel();
    _peerTick = null;
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (_) {}
    notifyListeners();
  }

  void _sendPing() => _ws?.add(jsonEncode({'type': 'ping', 't0': _now()}));

  void _onMessage(dynamic data) {
    if (data is! String) return;
    final msg = jsonDecode(data);
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'pong':
        final t0 = (msg['t0'] as num?)?.toInt() ?? 0;
        final th = (msg['th'] as num?)?.toInt() ?? 0;
        final rtt = _now() - t0;
        if (rtt < _bestRtt) {
          _bestRtt = rtt;
          _offset = th - ((t0 + _now()) ~/ 2);
        }
        break;
      case 'state':
        final s = msg['state'];
        if (s is Map) unawaited(_applyState(s));
        break;
      case 'ended':
        unawaited(leaveParty());
        break;
    }
  }

  int _targetMs(int positionMs, bool playing, int hostTimeMs) {
    if (!playing) return positionMs < 0 ? 0 : positionMs;
    final t = positionMs + ((_now() + _offset) - hostTimeMs);
    return t < 0 ? 0 : t;
  }

  int? _lastPosition;
  bool _lastStatePlaying = false;
  int _lastHostTime = 0;

  Future<void> _applyState(Map state) async {
    final key = '${state['track_key']}';
    _lastPosition = (state['position_ms'] as num?)?.toInt() ?? 0;
    _lastStatePlaying = (state['playing'] as bool?) ?? false;
    _lastHostTime = (state['host_time_ms'] as num?)?.toInt() ?? 0;
    final target = _targetMs(_lastPosition!, _lastStatePlaying, _lastHostTime);

    if (key != _curKey) {
      _curKey = key;
      final row = TrackRow(
        id: int.tryParse(key) ?? 0,
        title: 'Party · $_hostName',
        artist: '',
        album: '',
        albumId: null,
        durationMs: 0,
        year: null,
        rating: 0,
        playedCount: 0,
        path: '$_base/v1/stream/$key?token=$_token',
      );
      await player.playQueue([row], 0);
      await player.seek(Duration(milliseconds: target));
    } else {
      _resyncTo(target);
    }
    if (!_lastStatePlaying && player.playing) {
      player.toggle(); // pause to match the host
    }
  }

  void _correctDrift() {
    if (!_joined || _curKey.isEmpty || !_lastStatePlaying) return;
    final target = _targetMs(_lastPosition ?? 0, true, _lastHostTime);
    _resyncTo(target);
  }

  void _resyncTo(int targetMs) {
    final drift = (player.position.inMilliseconds - targetMs).abs();
    if (drift > 100) {
      unawaited(player.seek(Duration(milliseconds: targetMs)));
    }
  }

  @override
  void dispose() {
    _hostTick?.cancel();
    _peerTick?.cancel();
    _ws?.close();
    super.dispose();
  }
}

/// Process-wide party controller.
final PartyController party = PartyController();
