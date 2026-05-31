import 'dart:math';

/// ReplayGain normalization mode.
enum ReplayGainMode { off, track, album }

/// Linear volume multiplier for ReplayGain. Returns 1.0 when off or when no
/// gain data is available for the chosen mode. `preampDb` is added to the tag
/// gain. Clamped to a sane range so a quiet track can't blow up the volume.
double replayGainFactor({
  required ReplayGainMode mode,
  double? trackDb,
  double? albumDb,
  double preampDb = 0,
}) {
  final db = switch (mode) {
    ReplayGainMode.off => null,
    ReplayGainMode.track => trackDb ?? albumDb,
    ReplayGainMode.album => albumDb ?? trackDb,
  };
  if (db == null) return 1.0;
  final factor = pow(10, (db + preampDb) / 20).toDouble();
  return factor.clamp(0.0, 4.0);
}
