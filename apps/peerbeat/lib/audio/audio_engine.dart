import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;

import '../src/rust/api/audio.dart' as rust;

/// Platform-agnostic audio transport.
///
/// Desktop (Windows/Linux) uses the Rust engine (rodio/cpal) over FRB; Android
/// uses ExoPlayer via just_audio. The UI talks only to this interface.
abstract class AudioEngine {
  factory AudioEngine.forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) return ExoPlayerEngine();
    return RustDesktopEngine();
  }

  Future<void> playPath(String path, {Duration? duration});

  /// Play a remote URL (LAN stream).
  Future<void> playUrl(String url, {Duration? duration});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// Volume in 0.0–1.0 (1.0 = unity).
  Future<void> setVolume(double volume);

  /// Playback speed (1.0 = normal). Desktop currently shifts pitch with speed.
  Future<void> setSpeed(double speed);

  /// 10-band graphic EQ. Gains are dB values for 31 Hz through 16 kHz.
  Future<void> setEq(List<double> gains, double preampDb);

  String? get lastError;

  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Duration get position;
  Duration get duration;
  bool get playing;

  Future<void> dispose();
}

/// Desktop: wraps the synchronous FRB audio API, polling it into streams.
class RustDesktopEngine implements AudioEngine {
  RustDesktopEngine() {
    _sweepStreamCache(); // best-effort: clear the previous session's stream cache
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll());
  }

  final _pos = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  Timer? _ticker;
  Duration _duration = Duration.zero;
  bool _lastPlaying = false;

  void _poll() {
    _pos.add(Duration(milliseconds: rust.audioPositionMs()));
    final p = rust.audioIsPlaying();
    if (p != _lastPlaying) {
      _lastPlaying = p;
      _playing.add(p);
    }
  }

  @override
  Future<void> playPath(String path, {Duration? duration}) async {
    rust.audioPlayPath(path: path);
    _duration = duration ?? Duration(milliseconds: rust.audioDurationMs());
    _setPlaying(true);
  }

  @override
  Future<void> playUrl(String url, {Duration? duration}) async {
    // rodio plays from a file; cache the LAN stream to disk (reused on replay,
    // swept on startup). True HTTP Range streaming is a later slice.
    try {
      final dir = await _streamCacheDir();
      final file = File('${dir.path}/${url.hashCode}.audio');
      if (!await file.exists() || await file.length() == 0) {
        final part = File('${file.path}.part');
        final client = HttpClient();
        try {
          final resp = await (await client.getUrl(Uri.parse(url))).close();
          if (resp.statusCode != 200) {
            throw Exception('HTTP ${resp.statusCode}');
          }
          await resp.pipe(part.openWrite());
          await part.rename(file.path); // atomic publish
        } finally {
          client.close();
        }
      }
      rust.audioPlayPath(path: file.path);
      _duration = duration ?? Duration(milliseconds: rust.audioDurationMs());
      _setPlaying(true);
    } catch (e) {
      _setPlaying(false);
      throw Exception('LAN stream playback failed: $e');
    }
  }

  static Directory? _cacheDir;
  static Future<Directory> _streamCacheDir() async {
    final dir = _cacheDir ??= Directory(
      '${Directory.systemTemp.path}/peerbeat_stream_cache',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _sweepStreamCache() async {
    try {
      final dir = Directory(
        '${Directory.systemTemp.path}/peerbeat_stream_cache',
      );
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    rust.audioPause();
    _setPlaying(false);
  }

  @override
  Future<void> resume() async {
    rust.audioResume();
    _setPlaying(true);
  }

  @override
  Future<void> stop() async {
    rust.audioStop();
    _setPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async =>
      rust.audioSeekMs(ms: position.inMilliseconds);

  @override
  Future<void> setVolume(double volume) async =>
      rust.audioSetVolume(volume: volume);

  @override
  Future<void> setSpeed(double speed) async => rust.audioSetSpeed(speed: speed);

  @override
  Future<void> setEq(List<double> gains, double preampDb) async =>
      rust.audioSetEq(gains: gains, preampDb: preampDb);

  void _setPlaying(bool p) {
    _lastPlaying = p;
    _playing.add(p);
  }

  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Duration get position => Duration(milliseconds: rust.audioPositionMs());
  @override
  Duration get duration => _duration == Duration.zero
      ? Duration(milliseconds: rust.audioDurationMs())
      : _duration;
  @override
  bool get playing => _lastPlaying;
  @override
  String? get lastError => rust.audioLastError();

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _pos.close();
    await _playing.close();
  }
}

/// Android: ExoPlayer via just_audio.
class ExoPlayerEngine implements AudioEngine {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  @override
  Future<void> playPath(String path, {Duration? duration}) async {
    await _player.setFilePath(path);
    _player.play(); // do not await: completes only when playback ends
  }

  @override
  Future<void> playUrl(String url, {Duration? duration}) async {
    await _player.setUrl(url);
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() async => _player.play();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setEq(List<double> gains, double preampDb) async {
    // Android platform EQ lands with the Android audio-effects pass. Persisting
    // and exposing the same controls now keeps settings cross-platform.
  }

  @override
  String? get lastError => null;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Duration get position => _player.position;
  @override
  Duration get duration => _player.duration ?? Duration.zero;
  @override
  bool get playing => _player.playing;

  @override
  Future<void> dispose() => _player.dispose();
}
