import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../audio/replay_gain.dart';
import '../src/rust/api/audio.dart' show OutputDeviceRow;
import '../src/rust/api/library.dart';
import '../src/rust/db/tracks.dart';
import '../ui/theme.dart' show accentFromArt;

export '../audio/replay_gain.dart' show ReplayGainMode;

enum RepeatMode { off, all, one }

const _kResumeTrack = 'resume.track_id';
const _kResumePos = 'resume.position_ms';
const _kRgMode = 'audio.rg_mode';
const _kRgPreamp = 'audio.rg_preamp';
const _kEqEnabled = 'audio.eq_enabled';
const _kEqGains = 'audio.eq_gains';
const _kEqPreamp = 'audio.eq_preamp';
const _kOutputDevice = 'audio.output_device';
const _kStereoWidth = 'audio.stereo_width';
const _kCrossfade = 'audio.crossfade';
const _kDynamicTheme = 'ui.dynamic_theme';

/// App-wide playback state: wraps the platform [AudioEngine], owns the queue +
/// play order (shuffle), and exposes prev/next/toggle/seek/shuffle/repeat/mute.
/// A single instance ([player]) lives above the navigator so the mini-player
/// persists across screens.
class PlayerController extends ChangeNotifier {
  PlayerController({AudioEngine? engine})
    : this._(engine: engine, persistSettings: true);

  @visibleForTesting
  PlayerController.forTest({required AudioEngine engine})
    : this._(engine: engine, persistSettings: false);

  PlayerController._({AudioEngine? engine, required this._persistSettings})
    : _engine = engine ?? AudioEngine.forPlatform(),
      super() {
    _posSub = _engine.positionStream.listen((p) {
      // Ignore engine ticks until a track is actually loaded — otherwise the
      // desktop poller (which reads 0 while idle) would clobber a restored
      // resume bookmark to 0:00 and then persist that 0.
      if (!_engineLoaded) return;
      _setPosition(p);
      _scheduleMaybeAdvance();
      _persistResume();
      // Deliberately no notifyListeners() here: position flows via
      // positionNotifier only. See positionNotifier's doc comment.
    });
    _playSub = _engine.playingStream.listen((p) {
      if (!p && !_userPaused && current != null) {
        final d = duration;
        final nearEnd =
            d != Duration.zero &&
            _position >= d - const Duration(milliseconds: 500);
        if (!nearEnd) return;
      }
      final wasPlaying = _playing;
      _playing = p;
      if (wasPlaying && !p) {
        _scheduleMaybeAdvance();
      }
      notifyListeners();
    });
  }

  final AudioEngine _engine;
  final bool _persistSettings;
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
  ReplayGainMode _rgMode = ReplayGainMode.off;
  double _rgPreampDb = 0.0;
  double _rgFactor = 1.0; // cached multiplier for the current track
  bool _eqEnabled = false;
  List<double> _eqGains = List.filled(10, 0.0);
  double _eqPreampDb = 0.0;
  String _outputDeviceId = 'default';
  double _stereoWidth = 1.0;
  double _crossfade = 0.0; // seconds; 0 = off (default)
  Duration _position = Duration.zero;
  // High-frequency playback position (engine poll, ~5x/s). Deliberately NOT
  // routed through notifyListeners — a position tick must not rebuild the whole
  // UI, or the tooltip/Slider OverlayPortals churning on every tick trip the
  // Overlay's `_skipMarkNeedsLayout` assertion (full-screen red crash). Only the
  // scrubbers/time labels/lyrics listen here; everything else listens to the
  // ChangeNotifier, which now fires only on real state changes (track, play/pause,
  // volume, shuffle, ...). This also stops the entire UI rebuilding 5x/second.
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  // Album-art accent for dynamic theming. Updated ONLY on track change (never on
  // the position tick) and consumed by the app shell via AnimatedTheme — so the
  // root theme never rebuilds mid-position-tick (the old dynamic-theme crash).
  final ValueNotifier<Color?> accentColor = ValueNotifier(null);
  bool _dynamicTheme = true;
  bool get dynamicTheme => _dynamicTheme;
  String? _lastError;
  // Resume support: a restored session is shown paused with the engine not yet
  // holding the track; the first play loads it and seeks to `_resumeFrom`.
  bool _engineLoaded = false;
  Duration? _resumeFrom;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  int _generation = 0;
  int? _pendingAdvanceGeneration;

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
  ReplayGainMode get replayGainMode => _rgMode;
  double get replayGainPreampDb => _rgPreampDb;
  bool get eqEnabled => _eqEnabled;
  List<double> get eqGains => List.unmodifiable(_eqGains);
  double get eqPreampDb => _eqPreampDb;
  String get outputDeviceId => _outputDeviceId;
  double get stereoWidth => _stereoWidth;
  double get crossfade => _crossfade;
  Duration get position => _position;

  // Keep _position and the high-frequency notifier in lockstep.
  void _setPosition(Duration p) {
    _position = p;
    positionNotifier.value = p;
  }

  Duration get duration => current == null
      ? Duration.zero
      : Duration(milliseconds: current!.durationMs);
  bool get hasNext =>
      _order.isNotEmpty &&
      (_pos + 1 < _order.length || _repeat == RepeatMode.all);
  bool get hasPrevious =>
      _order.isNotEmpty && (_pos > 0 || _repeat == RepeatMode.all);
  String? get lastError => _lastError;

  /// Play [tracks] starting at [index] (the new queue). If [startAt] is given
  /// the track loads already positioned there (used by party sync to avoid a
  /// brief play-from-zero before the seek lands).
  Future<void> playQueue(
    List<TrackRow> tracks,
    int index, {
    Duration? startAt,
  }) async {
    // A fresh user choice supersedes any restored bookmark, unless an explicit
    // start position was requested.
    _resumeFrom = (startAt != null && startAt > Duration.zero) ? startAt : null;
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

  /// Reorder a track within "Up next" (indices are into [upNext]). [newIndex] is
  /// already adjusted for the removal (ReorderableListView.onReorderItem).
  void reorderUpNext(int oldIndex, int newIndex) {
    final base = _pos + 1;
    if (base < 1) return;
    final upNextLen = _order.length - base;
    if (oldIndex < 0 || oldIndex >= upNextLen) return;
    newIndex = newIndex.clamp(0, upNextLen - 1);
    final item = _order.removeAt(base + oldIndex);
    _order.insert(base + newIndex, item);
    notifyListeners();
  }

  /// Remove a track from "Up next" by its [upNext] index.
  void removeFromUpNext(int upNextIndex) {
    final idx = _pos + 1 + upNextIndex;
    if (idx <= _pos || idx >= _order.length) return;
    _order.removeAt(idx);
    notifyListeners();
  }

  // ── Sleep timer ──────────────────────────────────────────────────────────
  Timer? _sleepTimer;
  DateTime? _sleepDeadline;
  bool get sleepActive => _sleepTimer != null;

  /// Time left on the sleep timer, or null if it's off.
  Duration? get sleepRemaining {
    final d = _sleepDeadline;
    if (d == null) return null;
    final r = d.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// Arm (or, with null/zero, cancel) the sleep timer. On fire it fades the
  /// volume out then pauses, restoring the volume so the next play is normal.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    if (duration != null && duration > Duration.zero) {
      _sleepDeadline = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, _onSleep);
    }
    notifyListeners();
  }

  Future<void> _onSleep() async {
    _sleepTimer = null;
    _sleepDeadline = null;
    notifyListeners();
    final restore = _volume;
    for (var step = 1; step <= 10 && _playing; step++) {
      _volume = (restore * (1 - step / 10)).clamp(0.0, 1.0);
      _applyVolume();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (_playing) toggle(); // pause
    _volume = restore;
    _applyVolume();
    notifyListeners();
  }

  void playNext(TrackRow t) {
    _queue = [..._queue, t];
    final newIndex = _queue.length - 1;
    final insertAt = _pos < 0 ? 0 : (_pos + 1).clamp(0, _order.length);
    _order = [..._order]..insert(insertAt, newIndex);
    if (_pos < 0) {
      _pos = 0;
      // Fire-and-forget — _playCurrent sets _lastError on failure (mirrors toggle()).
      unawaited(_playCurrent());
    } else {
      notifyListeners();
    }
  }

  void setShuffle(bool on) {
    if (on == _shuffle) return;
    _shuffle = on;
    if (_order.isNotEmpty && _pos >= 0 && _pos < _order.length) {
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
    if (_order.isEmpty || _pos < 0 || _pos >= _order.length) return;
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
    _applyVolume();
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _muted = false;
    _applyVolume();
    notifyListeners();
  }

  /// Push the effective output volume (user volume × ReplayGain, or 0 if muted).
  void _applyVolume() {
    _engine.setVolume((_muted ? 0.0 : _volume) * _rgFactor);
  }

  void _recomputeRg() {
    _rgFactor = replayGainFactor(
      mode: _rgMode,
      trackDb: current?.replaygainTrackDb,
      albumDb: current?.replaygainAlbumDb,
      preampDb: _rgPreampDb,
    );
  }

  void setReplayGainMode(ReplayGainMode mode) {
    _rgMode = mode;
    _recomputeRg();
    _applyVolume();
    unawaited(settingsSet(key: _kRgMode, value: mode.name));
    notifyListeners();
  }

  void setReplayGainPreamp(double db) {
    _rgPreampDb = db.clamp(-15.0, 15.0);
    _recomputeRg();
    _applyVolume();
    unawaited(settingsSet(key: _kRgPreamp, value: '$_rgPreampDb'));
    notifyListeners();
  }

  void setEqEnabled(bool enabled) {
    _eqEnabled = enabled;
    _applyEq();
    unawaited(settingsSet(key: _kEqEnabled, value: enabled ? '1' : '0'));
    notifyListeners();
  }

  void setEqBand(int index, double gainDb) {
    if (index < 0 || index >= _eqGains.length) return;
    _eqGains = [..._eqGains]..[index] = gainDb.clamp(-12.0, 12.0);
    _eqEnabled = true;
    _applyEq();
    _persistEq();
    notifyListeners();
  }

  void setEqPreamp(double db) {
    _eqPreampDb = db.clamp(-15.0, 15.0);
    _eqEnabled = true;
    _applyEq();
    _persistEq();
    notifyListeners();
  }

  void setEqPreset(List<double> gains, double preampDb) {
    if (gains.length != 10) return;
    _eqGains = [for (final g in gains) g.clamp(-12.0, 12.0).toDouble()];
    _eqPreampDb = preampDb.clamp(-15.0, 15.0);
    _eqEnabled =
        _eqPreampDb.abs() > 0.001 || _eqGains.any((g) => g.abs() > 0.001);
    _applyEq();
    _persistEq();
    unawaited(settingsSet(key: _kEqEnabled, value: _eqEnabled ? '1' : '0'));
    notifyListeners();
  }

  void resetEq() => setEqPreset(List.filled(10, 0.0), 0.0);

  Future<List<OutputDeviceRow>> outputDevices() => _engine.outputDevices();

  Future<void> setOutputDevice(String id) async {
    _outputDeviceId = id;
    await _engine.setOutputDevice(id == 'default' ? null : id);
    unawaited(settingsSet(key: _kOutputDevice, value: id));
    notifyListeners();
  }

  void setStereoWidth(double width) {
    _stereoWidth = width.clamp(0.0, 2.0);
    unawaited(_engine.setStereoWidth(_stereoWidth));
    unawaited(settingsSet(key: _kStereoWidth, value: '$_stereoWidth'));
    notifyListeners();
  }

  /// Crossfade between tracks, 0–12 s (0 = off). Applies to the next transition.
  void setCrossfade(double secs) {
    _crossfade = secs.clamp(0.0, 12.0);
    unawaited(_engine.setCrossfade(_crossfade));
    unawaited(settingsSet(key: _kCrossfade, value: '$_crossfade'));
    notifyListeners();
  }

  /// Toggle album-art dynamic theming. When off, the accent clears (the app
  /// falls back to its default seed); when on, recompute for the current track.
  void setDynamicTheme(bool on) {
    _dynamicTheme = on;
    if (on) {
      unawaited(_updateAccent(current));
    } else {
      accentColor.value = null;
    }
    unawaited(settingsSet(key: _kDynamicTheme, value: on ? '1' : '0'));
    notifyListeners();
  }

  /// Recompute the album-art accent for [t]. Best-effort and async; a stale
  /// result for a track we've since left is discarded.
  Future<void> _updateAccent(TrackRow? t) async {
    if (!_dynamicTheme) {
      accentColor.value = null;
      return;
    }
    final c = await accentFromArt(t?.artPath);
    if (identical(current, t) || current?.id == t?.id) {
      accentColor.value = c;
    }
  }

  void _applyEq() {
    final gains = _eqEnabled ? _eqGains : List<double>.filled(10, 0.0);
    final preamp = _eqEnabled ? _eqPreampDb : 0.0;
    unawaited(_engine.setEq(gains, preamp));
  }

  void _persistEq() {
    unawaited(settingsSet(key: _kEqGains, value: jsonEncode(_eqGains)));
    unawaited(settingsSet(key: _kEqPreamp, value: '$_eqPreampDb'));
  }

  /// Load persisted audio settings (ReplayGain). Best-effort; call once at start.
  Future<void> loadAudioSettings() async {
    try {
      final mode = await settingsGet(key: _kRgMode);
      if (mode != null) {
        _rgMode = ReplayGainMode.values.firstWhere(
          (m) => m.name == mode,
          orElse: () => ReplayGainMode.off,
        );
      }
      final preamp = await settingsGet(key: _kRgPreamp);
      if (preamp != null) {
        _rgPreampDb = (double.tryParse(preamp) ?? 0.0).clamp(-15.0, 15.0);
      }
      _eqEnabled = (await settingsGet(key: _kEqEnabled)) == '1';
      final eqGains = await settingsGet(key: _kEqGains);
      if (eqGains != null) {
        final decoded = jsonDecode(eqGains);
        if (decoded is List && decoded.length == 10) {
          _eqGains = [
            for (final g in decoded)
              ((g is num ? g.toDouble() : 0.0).clamp(-12.0, 12.0)).toDouble(),
          ];
        }
      }
      final eqPreamp = await settingsGet(key: _kEqPreamp);
      if (eqPreamp != null) {
        _eqPreampDb = (double.tryParse(eqPreamp) ?? 0.0).clamp(-15.0, 15.0);
      }
      _outputDeviceId = await settingsGet(key: _kOutputDevice) ?? 'default';
      final stereoWidth = await settingsGet(key: _kStereoWidth);
      if (stereoWidth != null) {
        _stereoWidth = (double.tryParse(stereoWidth) ?? 1.0).clamp(0.0, 2.0);
      }
      final crossfade = await settingsGet(key: _kCrossfade);
      if (crossfade != null) {
        _crossfade = (double.tryParse(crossfade) ?? 0.0).clamp(0.0, 12.0);
      }
      final dyn = await settingsGet(key: _kDynamicTheme);
      if (dyn != null) _dynamicTheme = dyn == '1';
      _recomputeRg();
      _applyVolume();
      _applyEq();
      unawaited(_engine.setStereoWidth(_stereoWidth));
      unawaited(_engine.setCrossfade(_crossfade));
      try {
        await _engine.setOutputDevice(
          _outputDeviceId == 'default' ? null : _outputDeviceId,
        );
      } catch (_) {
        _outputDeviceId = 'default';
        await _engine.setOutputDevice(null);
        unawaited(settingsSet(key: _kOutputDevice, value: 'default'));
      }
      notifyListeners();
    } catch (_) {
      // best-effort
    }
  }

  /// Set playback speed (0.5–2×). Pitch-preserving on Linux/macOS (Signalsmith
  /// Stretch); on Windows it currently falls back to a pitch-shifting resample.
  /// The range matches the engine's safe bounds so the UI never shows a speed
  /// the engine would silently clamp away.
  void setSpeed(double s) {
    _speed = s.clamp(0.5, 2.0);
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
    _generation++;
    final resume = _resumeFrom;
    _setPosition(resume ?? Duration.zero);
    _playing = true;
    _userPaused = false;
    _lastError = null;
    unawaited(_updateAccent(t)); // album-art accent for dynamic theming
    notifyListeners();
    try {
      final p = t.path;
      // Metadata for the OS media session (Android lockscreen/notification).
      final tag = MediaTag(
        id: '${t.id}',
        title: t.title.isEmpty ? 'Unknown title' : t.title,
        artist: t.artist,
        album: t.album,
        artUri: (t.artPath != null && t.artPath!.isNotEmpty)
            ? Uri.file(t.artPath!)
            : null,
        durationMs: t.durationMs,
      );
      if (p.startsWith('http://') || p.startsWith('https://')) {
        await _engine.playUrl(p, duration: duration, tag: tag);
      } else {
        await _engine.playPath(p, duration: duration, tag: tag);
      }
      _engineLoaded = true;
      if (_persistSettings && !p.startsWith('http')) {
        // Record a local play (feeds Most/Recently-Played + smart-playlist
        // played_count rules). Skipped for LAN streams (remote ids aren't local).
        unawaited(libraryMarkPlayed(trackId: t.id));
      }
      // Re-apply speed + ReplayGain volume: a fresh source (or a restarted
      // worker) resets them, and the gain is per-track.
      if (_speed != 1.0) await _engine.setSpeed(_speed);
      _applyEq();
      await _engine.setStereoWidth(_stereoWidth);
      _recomputeRg();
      _applyVolume();
      if (resume != null) {
        _resumeFrom = null;
        // Best-effort: some formats can't seek far enough to a deep bookmark —
        // don't let that abort playback, just start from the top.
        try {
          await _engine.seek(resume);
        } catch (_) {}
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
      // Fire-and-forget — _playCurrent sets _lastError on failure.
      unawaited(_playCurrent());
    } else {
      _userPaused = false;
      _engine.resume();
    }
  }

  Future<void> seek(Duration p) async {
    // Before the engine holds the track (restored session), a scrub just moves
    // the pending resume target.
    if (!_engineLoaded) {
      _setPosition(p);
      _resumeFrom = p == Duration.zero ? null : p;
      _persistResume(force: true);
      notifyListeners();
      return;
    }
    final previous = _position;
    _setPosition(p);
    _lastError = null;
    notifyListeners();
    try {
      await _engine.seek(p);
    } catch (e) {
      _setPosition(previous);
      _lastError = _engine.lastError ?? e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Persist the resume bookmark (track id + position), throttled to once every
  // 5 s except when `force`d (pause / load) so the latest state survives a quit.
  void _persistResume({bool force = false}) {
    if (!_persistSettings) return;
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
      _setPosition(Duration(milliseconds: clamped));
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
  void _scheduleMaybeAdvance() {
    final generation = _generation;
    if (_pendingAdvanceGeneration == generation) return;
    _pendingAdvanceGeneration = generation;
    scheduleMicrotask(() {
      if (_pendingAdvanceGeneration != generation) return;
      _pendingAdvanceGeneration = null;
      _maybeAdvance(generation);
    });
  }

  Future<void> _maybeAdvance(int generation) async {
    if (generation != _generation) return;
    final d = duration;
    if (_advancing || _userPaused || current == null || d == Duration.zero) {
      return;
    }
    // With crossfade on, pre-advance ~crossfade seconds before the end so the
    // engine can overlap the outgoing tail with the incoming track. Skipped for
    // repeat-one (a track can't crossfade into itself) and very short tracks;
    // otherwise advance only once the track has actually ended.
    final crossfadeMs = (_crossfade * 1000).round();
    final crossfading =
        crossfadeMs >= 500 &&
        hasNext &&
        _repeat != RepeatMode.one &&
        d.inMilliseconds > crossfadeMs + 2000;
    final lead = crossfading
        ? Duration(milliseconds: crossfadeMs)
        : const Duration(milliseconds: 500);
    final nearEnd = _position >= d - lead;
    final ended = nearEnd && (crossfading || !_playing || _position >= d);
    if (!ended) return;
    _advancing = true;
    try {
      if (generation != _generation) return;
      if (_repeat == RepeatMode.one) {
        _setPosition(Duration.zero);
        await _playCurrent();
      } else if (hasNext) {
        await next();
      } else {
        _setPosition(d);
        _persistResume(force: true);
        notifyListeners();
      }
    } finally {
      _advancing = false;
    }
  }

  @override
  void dispose() {
    _posSub.cancel();
    _playSub.cancel();
    _sleepTimer?.cancel();
    _engine.dispose();
    positionNotifier.dispose();
    accentColor.dispose();
    super.dispose();
  }
}

/// Process-wide singleton (the app has one audio output).
final PlayerController player = PlayerController();
