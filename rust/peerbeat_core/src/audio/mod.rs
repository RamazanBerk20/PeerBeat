//! Desktop audio engine (Windows/Linux).
//!
//! `symphonia` decode → DSP graph → `rubato` resample → `cpal` output.
//! The DSP graph provides: a 10-band biquad EQ, ReplayGain pre-amp, optional
//! stereo widening, a dual-decoder equal-power mixer for gapless + configurable
//! crossfade (0–12 s), and pitch-preserving variable speed (0.5–2×).
//!
//! All transport mutations go through one serialized, coalescing command queue
//! (last-write-wins on seek/volume); position is interpolated locally between
//! decoder ticks and streamed to Dart, meeting the < 50 ms scrub target.
//!
//! On Android this module is unused — playback there is ExoPlayer (Dart side).
//!
//! Implemented in **M1** (transport + gapless/crossfade + speed) and extended in
//! **M2** (EQ, ReplayGain, output-device selection, stereo widening).

// Submodules land in M1:
// mod engine;       // cpal stream + command queue + position stream
// mod decoder;      // symphonia source + dual-decoder crossfade mixer
// mod dsp;          // biquad EQ, replaygain, widener, time-stretch
// mod devices;      // output-device enumeration + selection
