import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../src/rust/db/tracks.dart';

/// App-wide playback state: wraps the platform [AudioEngine], owns the queue,
/// and exposes prev/next/toggle/seek. A single instance ([player]) lives above
/// the navigator so the mini-player persists across screens.
class PlayerController extends ChangeNotifier {
  PlayerController() {
    _engine.positionStream.listen((p) {
      _position = p;
      _maybeAdvance();
      notifyListeners();
    });
    _engine.playingStream.listen((p) {
      _playing = p;
      notifyListeners();
    });
  }

  final AudioEngine _engine = AudioEngine.forPlatform();

  List<TrackRow> _queue = const [];
  int _index = -1;
  bool _playing = false;
  Duration _position = Duration.zero;

  TrackRow? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;
  bool get playing => _playing;
  Duration get position => _position;
  Duration get duration => current == null
      ? Duration.zero
      : Duration(milliseconds: current!.durationMs);
  bool get hasNext => _index + 1 < _queue.length;
  bool get hasPrevious => _index > 0;

  /// Play [tracks] starting at [index] (the new queue).
  void playQueue(List<TrackRow> tracks, int index) {
    _queue = List.unmodifiable(tracks);
    _playAt(index);
  }

  void playSingle(TrackRow t) => playQueue([t], 0);

  void _playAt(int i) {
    if (i < 0 || i >= _queue.length) return;
    _index = i;
    _position = Duration.zero;
    _playing = true;
    _engine.playPath(current!.path, duration: duration);
    notifyListeners();
  }

  void next() {
    if (hasNext) _playAt(_index + 1);
  }

  /// Previous restarts the current track if >3 s in, else goes to the prior track.
  void previous() {
    if (_position.inSeconds > 3) {
      seek(Duration.zero);
    } else if (hasPrevious) {
      _playAt(_index - 1);
    }
  }

  void toggle() {
    if (current == null) return;
    if (_playing) {
      _engine.pause();
    } else {
      _engine.resume();
    }
  }

  void seek(Duration p) {
    _engine.seek(p);
    _position = p;
    notifyListeners();
  }

  // Auto-advance: when the engine reports stopped at (or past) the end.
  bool _advancing = false;
  void _maybeAdvance() {
    final d = duration;
    if (_advancing || current == null || d == Duration.zero) return;
    if (!_playing && _position >= d - const Duration(milliseconds: 600)) {
      _advancing = true;
      if (hasNext) {
        next();
      }
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _advancing = false;
      });
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

/// Process-wide singleton (the app has one audio output).
final PlayerController player = PlayerController();
