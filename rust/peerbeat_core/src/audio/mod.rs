//! Desktop audio engine (Windows/Linux).
//!
//! **Current implementation** ([`engine`]): a `rodio`-based transport on a
//! dedicated audio thread driven by a serialized command channel (a fresh symphonia
//! reader handles AAC/M4A; rodio's decoders handle the rest). A real-time DSP chain
//! applies a 10-band biquad EQ ([`eq`]), a ReplayGain pre-amp, and optional stereo
//! widening ([`widen`]). Position is published via shared atomics the FRB layer
//! polls; transport mutations are last-write-wins on the command channel.
//!
//! **Not yet built here** (see the roadmap / `docs/STATUS.md`): gapless, configurable
//! crossfade (0–12 s), and *pitch-preserving* variable speed. rodio's `set_speed`
//! currently shifts pitch with speed; the planned `symphonia → DSP → rubato → cpal`
//! pipeline (dual-decoder crossfade mixer + a time-stretch stage) replaces this engine
//! to deliver those.
//!
//! On Android this module is unused — playback there is ExoPlayer (Dart side).

mod engine;
mod eq;
mod widen;
pub use engine::AudioEngine;

// Planned: replace the rodio engine with a custom symphonia→cpal pipeline:
// mod decoder;      // symphonia source + dual-decoder crossfade mixer
// mod dsp;          // biquad EQ, replaygain, widener, time-stretch
// mod devices;      // output-device enumeration + selection
