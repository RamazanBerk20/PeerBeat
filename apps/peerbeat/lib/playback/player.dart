import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../src/rust/db/tracks.dart';

enum RepeatMode { off, all, one }

/// App-wide playback state: wraps the platform [AudioEngine], owns the queue +
/// play order (shuffle), and exposes prev/next/toggle/seek/shuffle/repeat/mute.
/// A single instance ([player]) lives above the navigator so the mini-player
/// persists across screens.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    _posSub = _engine.positionStream.listen((p) {
      _position = p;
      _maybeAdvance();
      notifyListeners();
    });
    _playSub = _engine.playingStream.listen((p) {
      _playing = p;
      notifyListeners();
    });
  }

  final AudioEngine _engine = AudioEngine.forPlatform();
  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<bool> _playSub;

  List<TrackRow> _queue = []; // tracks in their original (added) order
  List<int> _order = []; // play order: indices into _queue
  int _pos = -1; // index into _order
  bool _playing = false;
  bool _userPaused = false; // distinguishes a user pause from a track ending
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;
  double _volume = 1.0;
  bool _muted = false;
  Duration _position = Duration.zero;
  String? _lastError;

  TrackRow? get current =>
      (_pos >= 0 && _pos < _order.length) ? _queue[_order[_pos]] : null;
  List<TrackRow> get queue => [for (final i in _order) _queue[i]];
  bool get playing => _playing;
  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;
  double get volume => _volume;
  bool get muted => _muted;
  Duration get position => _position;
  Duration get duration => current == null
      ? Duration.zero
      : Duration(milliseconds: current!.durationMs);
  bool get hasNext =>
      _order.isNotEmpty &&
      (_pos + 1 < _order.length || _repeat == RepeatMode.all);
  bool get hasPrevious =>
      _order.isNotEmpty && (_pos > 0 || _repeat == RepeatMode.all);
  String? get lastError => _lastError;

  /// Play [tracks] starting at [index] (the new queue).
  Future<void> playQueue(List<TrackRow> tracks, int index) async {
    _queue = List.of(tracks);
    _order = List<int>.generate(_queue.length, (i) => i);
    _pos = index.clamp(0, _order.isEmpty ? 0 : _order.length - 1);
    if (_shuffle) _shuffleKeepingCurrent();
    await _playCurrent();
  }

  Future<void> playSingle(TrackRow t) => playQueue([t], 0);

  void addToQueue(TrackRow t) {
    _queue = [..._queue, t];
    _order = [..._order, _queue.length - 1];
    notifyListeners();
  }

  void playNext(TrackRow t) {
    _queue = [..._queue, t];
    final newIndex = _queue.length - 1;
    final insertAt = _pos < 0 ? 0 : (_pos + 1).clamp(0, _order.length);
    _order = [..._order]..insert(insertAt, newIndex);
    if (_pos < 0) {
      _pos = 0;
      _playCurrent();
    } else {
      notifyListeners();
    }
  }

  void setShuffle(bool on) {
    if (on == _shuffle) return;
    _shuffle = on;
    if (_order.isNotEmpty) {
      final currentTrack = _order[_pos];
      if (on) {
        _shuffleKeepingCurrent();
      } else {
        _order = List<int>.generate(_queue.length, (i) => i);
        _pos = _order.indexOf(currentTrack);
      }
    }
    notifyListeners();
  }

  void _shuffleKeepingCurrent() {
    if (_order.isEmpty) return;
    final currentTrack = _order[_pos];
    final rest = [..._order]..removeAt(_pos);
    rest.shuffle(Random());
    _order = [currentTrack, ...rest];
    _pos = 0;
  }

  void cycleRepeat() {
    _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    _engine.setVolume(_muted ? 0.0 : _volume);
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _muted = false;
    _engine.setVolume(_volume);
    notifyListeners();
  }

  Future<void> next() async {
    if (_order.isEmpty) return;
    if (_pos + 1 < _order.length) {
      _pos++;
    } else if (_repeat == RepeatMode.all) {
      _pos = 0;
    } else {
      return; // end of queue
    }
    await _playCurrent();
  }

  /// Previous restarts the current track if >3 s in, else goes to the prior track.
  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_pos > 0) {
      _pos--;
    } else if (_repeat == RepeatMode.all && _order.isNotEmpty) {
      _pos = _order.length - 1;
    } else {
      await seek(Duration.zero);
      return;
    }
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final t = current;
    if (t == null) return;
    _position = Duration.zero;
    _playing = true;
    _userPaused = false;
    _lastError = null;
    notifyListeners();
    try {
      final p = t.path;
      if (p.startsWith('http://') || p.startsWith('https://')) {
        await _engine.playUrl(p, duration: duration);
      } else {
        await _engine.playPath(p, duration: duration);
      }
    } catch (e) {
      _playing = false;
      _lastError = _engine.lastError ?? e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void toggle() {
    if (current == null) return;
    if (_playing) {
      _userPaused = true;
      _engine.pause();
    } else {
      _userPaused = false;
      _engine.resume();
    }
  }

  Future<void> seek(Duration p) async {
    final previous = _position;
    _position = p;
    _lastError = null;
    notifyListeners();
    try {
      await _engine.seek(p);
    } catch (e) {
      _position = previous;
      _lastError = _engine.lastError ?? e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Auto-advance when the current track ends. Honors repeat mode and guards
  // against a user pause near the end and re-entrancy while advancing.
  bool _advancing = false;
  Future<void> _maybeAdvance() async {
    final d = duration;
    if (_advancing || _userPaused || current == null || d == Duration.zero) {
      return;
    }
    final ended =
        !_playing && _position >= d - const Duration(milliseconds: 400);
    if (!ended) return;
    _advancing = true;
    try {
      if (_repeat == RepeatMode.one) {
        await _playCurrent();
      } else if (hasNext) {
        await next();
      }
    } finally {
      _advancing = false;
    }
  }

  @override
  void dispose() {
    _posSub.cancel();
    _playSub.cancel();
    _engine.dispose();
    super.dispose();
  }
}

/// Process-wide singleton (the app has one audio output).
final PlayerController player = PlayerController();
