import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../src/rust/db/tracks.dart';

/// App-wide playback state: wraps the platform [AudioEngine], owns the queue,
/// and exposes prev/next/toggle/seek. A single instance ([player]) lives above
/// the navigator so the mini-player persists across screens.
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

  List<TrackRow> _queue = [];
  int _index = -1;
  bool _playing = false;
  bool _userPaused = false; // distinguishes a user pause from a track ending
  Duration _position = Duration.zero;
  String? _lastError;

  TrackRow? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  List<TrackRow> get queue => List.unmodifiable(_queue);
  bool get playing => _playing;
  Duration get position => _position;
  Duration get duration => current == null
      ? Duration.zero
      : Duration(milliseconds: current!.durationMs);
  bool get hasNext => _index + 1 < _queue.length;
  bool get hasPrevious => _index > 0;
  String? get lastError => _lastError;

  /// Play [tracks] starting at [index] (the new queue).
  Future<void> playQueue(List<TrackRow> tracks, int index) async {
    _queue = List.unmodifiable(tracks);
    await _playAt(index);
  }

  Future<void> playSingle(TrackRow t) => playQueue([t], 0);

  void addToQueue(TrackRow t) {
    _queue = [..._queue, t];
    notifyListeners();
  }

  void playNext(TrackRow t) {
    final insertAt = _index < 0 ? 0 : (_index + 1).clamp(0, _queue.length);
    _queue = [..._queue]..insert(insertAt, t);
    if (_index < 0) {
      _playAt(0);
    } else {
      notifyListeners();
    }
  }

  Future<void> _playAt(int i) async {
    if (i < 0 || i >= _queue.length) return;
    _index = i;
    _position = Duration.zero;
    _playing = true;
    _userPaused = false;
    _lastError = null;
    notifyListeners();
    final p = current!.path;
    try {
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

  Future<void> next() async {
    if (hasNext) await _playAt(_index + 1);
  }

  /// Previous restarts the current track if >3 s in, else goes to the prior track.
  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (hasPrevious) {
      await _playAt(_index - 1);
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

  // Auto-advance to the next track when the current one ends. Guards against a
  // user pause near the end and against re-entrancy while advancing.
  bool _advancing = false;
  Future<void> _maybeAdvance() async {
    final d = duration;
    if (_advancing || _userPaused || current == null || d == Duration.zero) {
      return;
    }
    final ended =
        !_playing && _position >= d - const Duration(milliseconds: 400);
    if (ended && hasNext) {
      _advancing = true;
      try {
        await next();
      } finally {
        _advancing = false;
      }
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
