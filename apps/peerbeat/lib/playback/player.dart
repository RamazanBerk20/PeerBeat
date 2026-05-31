import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/tracks.dart';

enum RepeatMode { off, all, one }

const _kResumeTrack = 'resume.track_id';
const _kResumePos = 'resume.position_ms';

/// App-wide playback state: wraps the platform [AudioEngine], owns the queue +
/// play order (shuffle), and exposes prev/next/toggle/seek/shuffle/repeat/mute.
/// A single instance ([player]) lives above the navigator so the mini-player
/// persists across screens.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    _posSub = _engine.positionStream.listen((p) {
      // Ignore engine ticks until a track is actually loaded — otherwise the
      // desktop poller (which reads 0 while idle) would clobber a restored
      // resume bookmark to 0:00 and then persist that 0.
      if (!_engineLoaded) return;
      _position = p;
      _maybeAdvance();
      _persistResume();
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
  double _speed = 1.0;
  Duration _position = Duration.zero;
  String? _lastError;
  // Resume support: a restored session is shown paused with the engine not yet
  // holding the track; the first play loads it and seeks to `_resumeFrom`.
  bool _engineLoaded = false;
  Duration? _resumeFrom;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  TrackRow? get current =>
      (_pos >= 0 && _pos < _order.length) ? _queue[_order[_pos]] : null;
  List<TrackRow> get queue => [for (final i in _order) _queue[i]];

  /// The play-order position of the current track (index into [queue]), or -1.
  int get currentIndex => _pos;

  /// Tracks queued after the current one, in play order (for "Up next").
  List<TrackRow> get upNext => (_pos >= 0 && _pos + 1 < _order.length)
      ? [for (final i in _order.sublist(_pos + 1)) _queue[i]]
      : const [];
  bool get playing => _playing;
  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;
  double get volume => _volume;
  bool get muted => _muted;
  double get speed => _speed;
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
    _resumeFrom = null; // a fresh user choice supersedes any restored bookmark
    _queue = List.of(tracks);
    _order = List<int>.generate(_queue.length, (i) => i);
    _pos = index.clamp(0, _order.isEmpty ? 0 : _order.length - 1);
    if (_shuffle) _shuffleKeepingCurrent();
    await _playCurrent();
  }

  Future<void> playSingle(TrackRow t) => playQueue([t], 0);

  /// Jump to a track already in the queue by its play-order [index].
  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= _order.length) return;
    _resumeFrom = null;
    _pos = index;
    await _playCurrent();
  }

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

  void setRepeat(RepeatMode mode) {
    if (mode == _repeat) return;
    _repeat = mode;
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

  /// Set playback speed (0.25–4×). Desktop currently shifts pitch with speed.
  void setSpeed(double s) {
    _speed = s.clamp(0.25, 4.0);
    _engine.setSpeed(_speed);
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
    final resume = _resumeFrom;
    _position = resume ?? Duration.zero;
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
      _engineLoaded = true;
      // Re-apply speed: a fresh source (or a restarted worker) resets to 1×.
      if (_speed != 1.0) await _engine.setSpeed(_speed);
      if (resume != null) {
        _resumeFrom = null;
        await _engine.seek(resume);
      }
      _persistResume(force: true);
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
      _persistResume(force: true);
    } else if (!_engineLoaded) {
      // Restored session: load the track (seeks to the saved position).
      _playCurrent();
    } else {
      _userPaused = false;
      _engine.resume();
    }
  }

  Future<void> seek(Duration p) async {
    // Before the engine holds the track (restored session), a scrub just moves
    // the pending resume target.
    if (!_engineLoaded) {
      _position = p;
      _resumeFrom = p == Duration.zero ? null : p;
      _persistResume(force: true);
      notifyListeners();
      return;
    }
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

  // Persist the resume bookmark (track id + position), throttled to once every
  // 5 s except when `force`d (pause / load) so the latest state survives a quit.
  void _persistResume({bool force = false}) {
    final t = current;
    if (t == null) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastPersist).inSeconds < 5) return;
    _lastPersist = now;
    unawaited(settingsSet(key: _kResumeTrack, value: '${t.id}'));
    unawaited(
      settingsSet(key: _kResumePos, value: '${_position.inMilliseconds}'),
    );
  }

  /// Restore the last session at startup (after the library opens): show the
  /// last track paused at its saved position. The engine loads the file only
  /// when the user presses play. Best-effort — a missing/renamed track is
  /// silently ignored.
  Future<void> restoreSession() async {
    try {
      final id = int.tryParse(await settingsGet(key: _kResumeTrack) ?? '');
      if (id == null) return;
      final track = await libraryTrackById(trackId: id);
      if (track == null) return;
      final posMs =
          int.tryParse(await settingsGet(key: _kResumePos) ?? '') ?? 0;
      // Don't resume on the last second — restart that track from the top.
      final clamped = posMs >= track.durationMs - 1000
          ? 0
          : posMs.clamp(0, track.durationMs).toInt();
      _queue = [track];
      _order = [0];
      _pos = 0;
      _position = Duration(milliseconds: clamped);
      _resumeFrom = _position == Duration.zero ? null : _position;
      _engineLoaded = false;
      _playing = false;
      _userPaused = true; // guards _maybeAdvance against a near-end bookmark
      notifyListeners();
    } catch (_) {
      // best-effort: no resume on any failure
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
