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
//! On Android this module is unused — playback there is ExoPlayer (Dart side).

mod engine;
mod eq;
mod timestretch;
mod widen;
pub use engine::AudioEngine;

// Planned: replace the rodio engine with a custom symphonia→cpal pipeline:
// mod decoder;      // symphonia source + dual-decoder crossfade mixer
// mod dsp;          // biquad EQ, replaygain, widener, time-stretch
// mod devices;      // output-device enumeration + selection
