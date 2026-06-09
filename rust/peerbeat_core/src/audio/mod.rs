//! Desktop audio engine (Windows/Linux).
//!
//! **Current implementation** ([`engine`]): a `rodio`-based transport on a
//! dedicated audio thread driven by a serialized command channel (a fresh symphonia
//! reader handles AAC/M4A; rodio's decoders handle the rest). A real-time DSP chain
//! applies a 10-band biquad EQ ([`eq`]), a ReplayGain pre-amp, and optional stereo
//! widening ([`widen`]). Position is published via shared atomics the FRB layer
//! polls; transport mutations are last-write-wins on the command channel.
//!
//! Configurable crossfade (0–12 s, dual-sink, opt-in) and **pitch-preserving
//! variable speed** ([`timestretch`], via Signalsmith Stretch — engaged only when
//! speed != 1.0) are implemented here. **Not yet built**: true gapless playback
//! (see the roadmap / `docs/STATUS.md`).
//!
//! On Android this engine is unused — playback there is ExoPlayer (Dart side) —
//! so the whole rodio/cpal/DSP stack (and its native C++ runtime) is excluded
//! from the Android build; [`AudioEngine`] there is a no-op stub so the FRB
//! surface still compiles.

#[cfg(not(target_os = "android"))]
mod engine;
#[cfg(target_os = "android")]
#[path = "engine_stub.rs"]
mod engine;

#[cfg(not(target_os = "android"))]
mod eq;
#[cfg(not(target_os = "android"))]
pub mod spectrum;
#[cfg(not(target_os = "android"))]
mod timestretch;
#[cfg(not(target_os = "android"))]
mod widen;

pub use engine::AudioEngine;

/// Latest Now-Playing visualizer spectrum: `bands` log-spaced magnitudes (each
/// ~0..1). Silent (all-zero) on Android, where there is no desktop engine.
#[cfg(not(target_os = "android"))]
pub fn spectrum_bands(bands: usize) -> Vec<f32> {
    spectrum::compute(bands)
}
#[cfg(target_os = "android")]
pub fn spectrum_bands(bands: usize) -> Vec<f32> {
    vec![0.0; bands]
}
