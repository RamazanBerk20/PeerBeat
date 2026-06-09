import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart' as ja;

import '../net/tofu.dart';
import '../src/rust/api/audio.dart' as rust;
import '../util/log.dart';

/// Now-playing metadata for the OS media session (Android lockscreen /
/// notification). Desktop engines ignore it (MPRIS is fed separately). Kept
/// engine-agnostic so the abstract interface doesn't leak just_audio types.
class MediaTag {
  const MediaTag({
    required this.id,
    required this.title,
    this.artist = '',
    this.album = '',
    this.artUri,
    this.durationMs = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Uri? artUri;
  final int durationMs;
}

/// Platform-agnostic audio transport.
///
/// Desktop (Windows/Linux) uses the Rust engine (rodio/cpal) over FRB; Android
/// uses ExoPlayer via just_audio. The UI talks only to this interface.
abstract class AudioEngine {
  factory AudioEngine.forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) return ExoPlayerEngine();
    return RustDesktopEngine();
  }

  Future<void> playPath(String path, {Duration? duration, MediaTag? tag});

  /// Play a remote URL (LAN stream).
  Future<void> playUrl(String url, {Duration? duration, MediaTag? tag});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// Volume in 0.0–1.0 (1.0 = unity).
  Future<void> setVolume(double volume);

  /// Playback speed (0.5–2×, 1.0 = normal). Desktop is pitch-preserving
  /// (Signalsmith time-stretch); 1.0× is a bit-exact bypass.
  Future<void> setSpeed(double speed);

  /// Crossfade between tracks in seconds (0 disables). Desktop only.
  Future<void> setCrossfade(double secs);

  /// 10-band graphic EQ. Gains are dB values for 31 Hz through 16 kHz.
  Future<void> setEq(List<double> gains, double preampDb);

  /// Stereo width: 0.0 = mono, 1.0 = unchanged, 2.0 = widened.
  Future<void> setStereoWidth(double width);

  Future<List<rust.OutputDeviceRow>> outputDevices();
  Future<void> setOutputDevice(String? deviceId);

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
    // best-effort: clear the previous session's stream cache (fire-and-forget).
    unawaited(_sweepStreamCache());
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
  Future<void> playPath(
    String path, {
    Duration? duration,
    MediaTag? tag,
  }) async {
    // tag is unused on desktop — MPRIS metadata is published separately.
    rust.audioPlayPath(path: path);
    _duration = duration ?? Duration(milliseconds: rust.audioDurationMs());
    _setPlaying(true);
  }

  @override
  Future<void> playUrl(String url, {Duration? duration, MediaTag? tag}) async {
    // rodio plays from a file; cache the LAN stream to disk (reused on replay,
    // swept on startup). True HTTP Range streaming is a later slice.
    try {
      final dir = await _streamCacheDir();
      // Key on a stable hash of the host+path (NOT the volatile `?token=`), so the
      // same track reuses its cache within a session; `hashCode` could collide.
      final file = File('${dir.path}/${_cacheKey(url)}.audio');
      if (!await file.exists() || await file.length() == 0) {
        final part = File('${file.path}.part');
        // TOFU client: trusts a self-signed cert only if its fingerprint
        // belongs to a host we've already pinned (via the Network screen).
        final client = await tofuStreamClient();
        try {
          final resp = await (await client.getUrl(Uri.parse(url))).close();
          if (resp.statusCode != 200) {
            throw Exception('HTTP ${resp.statusCode}');
          }
          await resp.pipe(part.openWrite());
          await part.rename(file.path); // atomic publish
          unawaited(_capStreamCache(dir)); // bound disk use, oldest-first
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

  /// Deterministic, low-collision filename for a stream URL. FNV-1a over the
  /// host+path (query dropped) — no crypto dependency needed for a cache key.
  static String _cacheKey(String url) {
    final uri = Uri.tryParse(url);
    final basis = uri == null ? url : '${uri.host}:${uri.port}${uri.path}';
    var hash = 0xcbf29ce484222325;
    for (final c in basis.codeUnits) {
      hash = (hash ^ c) * 0x100000001b3;
    }
    return (hash & 0x7fffffffffffffff).toRadixString(16);
  }

  /// Cap of the on-disk stream cache. Streamed LAN audio is transient, so a
  /// generous bound is enough to avoid unbounded growth within a session.
  static const int _cacheCapBytes = 1500 * 1024 * 1024; // ~1.5 GB

  /// Evict oldest cached files once the cache exceeds [_cacheCapBytes].
  static Future<void> _capStreamCache(Directory dir) async {
    try {
      final files = <File>[];
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File) {
          files.add(e);
          total += await e.length();
        }
      }
      if (total <= _cacheCapBytes) return;
      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      for (final f in files) {
        if (total <= _cacheCapBytes) break;
        final len = await f.length();
        try {
          await f.delete();
          total -= len;
        } catch (_) {
          // skip a file we can't evict; the cap is best-effort
        }
      }
    } catch (e) {
      logErr('cache.cap', e);
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
          } catch (_) {
            // a single stale file we can't delete is harmless; skip it
          }
        }
      }
    } catch (e) {
      logErr('cache.sweep', e);
    }
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
  Future<void> setCrossfade(double secs) async =>
      rust.audioSetCrossfade(secs: secs);

  @override
  Future<void> setEq(List<double> gains, double preampDb) async =>
      rust.audioSetEq(gains: gains, preampDb: preampDb);

  @override
  Future<void> setStereoWidth(double width) async =>
      rust.audioSetStereoWidth(width: width);

  @override
  Future<List<rust.OutputDeviceRow>> outputDevices() async =>
      rust.audioOutputDevices();

  @override
  Future<void> setOutputDevice(String? deviceId) async =>
      rust.audioSetOutputDevice(deviceId: deviceId);

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
  // The platform graphic EQ, inserted into the player's audio pipeline. Its
  // `parameters` (and per-band gains) only resolve once a source has activated
  // the effect, so we cache the desired curve and (re)apply it after each load.
  final ja.AndroidEqualizer _eq = ja.AndroidEqualizer();
  late final ja.AudioPlayer _player = ja.AudioPlayer(
    audioPipeline: ja.AudioPipeline(androidAudioEffects: [_eq]),
  );

  // 10-band ISO octave centres (Hz), matching the desktop engine + the UI.
  static const _centers = <double>[
    31.25,
    62.5,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];
  List<double> _eqGains = List<double>.filled(10, 0.0);
  double _eqPreampDb = 0.0;
  bool _eqOn = false;

  // Metadata for the OS media session is published by PeerBeatAudioHandler
  // (audio_service) straight from the player, so the just_audio sources need no
  // MediaItem tag here.
  @override
  Future<void> playPath(
    String path, {
    Duration? duration,
    MediaTag? tag,
  }) async {
    await _player.setAudioSource(ja.AudioSource.uri(Uri.file(path)));
    unawaited(_pushEq()); // (re)apply once the effect activates on this source
    unawaited(
      _player.play(),
    ); // do not await: completes only when playback ends
  }

  @override
  Future<void> playUrl(String url, {Duration? duration, MediaTag? tag}) async {
    await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(url)));
    unawaited(_pushEq());
    unawaited(
      _player.play(),
    ); // do not await: completes only when playback ends
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
  Future<void> setCrossfade(double secs) async {
    // just_audio has no built-in crossfade; desktop-only for now.
  }

  @override
  Future<void> setEq(List<double> gains, double preampDb) async {
    _eqGains = gains.length == 10 ? gains : List<double>.filled(10, 0.0);
    _eqPreampDb = preampDb;
    _eqOn = preampDb.abs() > 0.01 || _eqGains.any((g) => g.abs() > 0.01);
    await _pushEq();
  }

  /// Interpolate the desired gain (dB) at [freq] from the 10-band curve, on a
  /// log-frequency axis (so it lands sensibly on the device's own band centres).
  double _gainAt(double freq) {
    if (freq <= _centers.first) return _eqGains.first;
    if (freq >= _centers.last) return _eqGains.last;
    for (var i = 0; i < _centers.length - 1; i++) {
      final lo = _centers[i], hi = _centers[i + 1];
      if (freq >= lo && freq <= hi) {
        final t = (_logf(freq) - _logf(lo)) / (_logf(hi) - _logf(lo));
        return _eqGains[i] + (_eqGains[i + 1] - _eqGains[i]) * t;
      }
    }
    return 0.0;
  }

  static double _logf(double x) => math.log(x) / math.ln10;

  /// Push the cached EQ curve onto the device equalizer. `parameters` resolves
  /// only after a source activates the effect; before then this just pends.
  Future<void> _pushEq() async {
    try {
      final params = await _eq.parameters;
      await _eq.setEnabled(_eqOn);
      if (!_eqOn) return;
      for (final band in params.bands) {
        final g = (_gainAt(band.centerFrequency) + _eqPreampDb).clamp(
          params.minDecibels,
          params.maxDecibels,
        );
        await band.setGain(g);
      }
    } catch (e) {
      logErr('android.eq', e);
    }
  }

  @override
  Future<void> setStereoWidth(double width) async {
    // Android platform effects land in the Android audio-effects pass.
  }

  @override
  Future<List<rust.OutputDeviceRow>> outputDevices() async => const [
    rust.OutputDeviceRow(
      id: 'default',
      name: 'Android audio output',
      isDefault: true,
    ),
  ];

  @override
  Future<void> setOutputDevice(String? deviceId) async {
    // Android routing is controlled by the OS; per-app routing lands later
    // where Android exposes it.
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
