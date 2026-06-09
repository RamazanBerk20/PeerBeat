import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../playback/player.dart';
import '../src/rust/api/network.dart';
import '../src/rust/db/tracks.dart';
import '../util/log.dart';
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
    } catch (e) {
      logErr('party.broadcast', e);
    }
  }

  Future<void> stopHosting() async {
    if (!_hosting) return;
    _hosting = false;
    _hostTick?.cancel();
    _hostTick = null;
    player.removeListener(_onHostChange);
    try {
      await netPartyStop();
    } catch (e) {
      logErr('party.stop', e);
    }
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
  // Sentinel for "no round-trip measured yet" — any real LAN RTT is far below it.
  static const int _noRtt = 1 << 30;
  int _bestRtt = _noRtt;
  String _curKey = '';
  Timer? _peerTick;

  // Reconnection state: distinguish a user/host-initiated leave (no retry) from
  // a transient socket drop (retry with capped exponential backoff).
  bool _intentionalLeave = false;
  Timer? _reconnectTimer;
  int _retryMs = 500;
  int _retryCount = 0;
  static const int _maxRetries = 8;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Join a host's party. `base`/`token` come from the normal "open host" flow
  /// (authenticate to the whole library, then join).
  Future<void> joinParty(String base, String token, String hostName) async {
    await leaveParty();
    _intentionalLeave = false;
    _base = base;
    _token = token;
    _hostName = hostName;
    _offset = 0;
    _bestRtt = _noRtt;
    _curKey = '';
    _retryMs = 500;
    _retryCount = 0;
    await _connect(); // throws on the first attempt so the UI can report failure
    notifyListeners();
  }

  /// Open the party WebSocket and start the clock-sync + drift timers. Reused by
  /// both [joinParty] and the reconnect path.
  Future<void> _connect() async {
    final base = _base!, token = _token!;
    // The party WS is token-gated server-side; carry the library-scope token in
    // the query (the host's Auth extractor reads `?token=` for header-less clients).
    final wsUrl =
        '${base.replaceFirst('https://', 'wss://')}/v1/party?token=$token';
    final client = await tofuStreamClient();
    try {
      _ws = await WebSocket.connect(wsUrl, customClient: client);
    } catch (e) {
      client.close();
      rethrow;
    }
    _joined = true;
    _retryMs = 500; // a successful connect resets the backoff
    _retryCount = 0;
    _ws!.listen(
      _onMessage,
      onDone: _onSocketClosed,
      onError: (_) => _onSocketClosed(),
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
  }

  /// Called when the socket closes unexpectedly. Schedules a reconnect unless
  /// the disconnect was deliberate (user left, or host ended the party).
  void _onSocketClosed() {
    _peerTick?.cancel();
    _peerTick = null;
    _ws = null;
    if (_intentionalLeave) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_retryCount >= _maxRetries) {
      logErr('party.reconnect', 'gave up after $_maxRetries attempts');
      unawaited(leaveParty());
      return;
    }
    final delay = _retryMs;
    _retryMs = (_retryMs * 2).clamp(500, 15000);
    _retryCount++;
    notifyListeners(); // surface "reconnecting" to the UI
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      if (_intentionalLeave) return;
      try {
        await _connect();
        notifyListeners();
      } catch (e) {
        logErr('party.reconnect', e);
        _scheduleReconnect();
      }
    });
  }

  /// True while the peer is mid-reconnect (socket dropped, retrying).
  bool get reconnecting => _joined && _ws == null && _reconnectTimer != null;

  Future<void> leaveParty() async {
    if (!_joined && _ws == null && _reconnectTimer == null) return;
    _intentionalLeave = true;
    _joined = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _peerTick?.cancel();
    _peerTick = null;
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (e) {
      logErr('party.leave', e);
    }
    notifyListeners();
  }

  void _sendPing() {
    final ws = _ws;
    if (ws == null) return; // socket dropped — the reconnect path will recover
    ws.add(jsonEncode({'type': 'ping', 't0': _now()}));
  }

  /// Ask the host to play one of its tracks (party "request a track"). No-op if
  /// not currently joined to a party.
  void requestTrack(int hostTrackId) {
    final ws = _ws;
    if (ws == null) {
      logErr('party.requestTrack', 'not connected');
      return;
    }
    ws.add(jsonEncode({'type': 'request', 'track_id': hostTrackId}));
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    final msg = jsonDecode(data);
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'pong':
        // Capture the receive time ONCE and reuse it for both the round-trip
        // estimate and the offset, or the two diverge (Cristian's algorithm).
        final t1 = _now();
        final t0 = (msg['t0'] as num?)?.toInt() ?? 0;
        final th = (msg['th'] as num?)?.toInt() ?? 0;
        final s = cristianSync(t0, th, t1);
        if (s.rttMs < _bestRtt) {
          _bestRtt = s.rttMs;
          _offset = s.offsetMs;
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
      // Load already positioned at the target so the peer never audibly plays
      // from 0 before the seek lands.
      await player.playQueue([row], 0, startAt: Duration(milliseconds: target));
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

/// Cristian's algorithm: estimate the host-clock offset and round-trip time
/// from one ping/pong. [t0] = local send time, [th] = host's stamp, [t1] =
/// local receive time (captured once). Offset assumes a symmetric path:
/// host_time ≈ local_time + offset.
@visibleForTesting
({int offsetMs, int rttMs}) cristianSync(int t0, int th, int t1) =>
    (offsetMs: th - ((t0 + t1) ~/ 2), rttMs: t1 - t0);

/// Process-wide party controller.
final PartyController party = PartyController();
