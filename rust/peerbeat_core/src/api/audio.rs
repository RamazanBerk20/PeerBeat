//! FRB audio transport API (desktop). Holds the engine in a process-wide
//! `OnceLock`, created lazily on first use. Calls are `sync` (they only push a
//! command or read an atomic) so the UI gets immediate, low-latency control.

use crate::audio::AudioEngine;
use std::sync::OnceLock;

static ENGINE: OnceLock<AudioEngine> = OnceLock::new();

fn engine() -> &'static AudioEngine {
    ENGINE.get_or_init(AudioEngine::new)
}

/// Load `path` and start playing it (replacing anything current).
#[flutter_rust_bridge::frb(sync)]
pub fn audio_play_path(path: String) -> Result<(), String> {
    engine().load(path)
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_pause() {
    engine().pause();
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_resume() {
    engine().resume();
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_stop() {
    engine().stop();
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_seek_ms(ms: i64) -> Result<(), String> {
    engine().seek(ms.max(0) as u64)
}

/// Volume 0.0–2.0 (1.0 = unity).
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_volume(volume: f64) {
    engine().set_volume(volume as f32);
}

/// Playback speed 0.25–4.0 (1.0 = normal). NOTE: rodio's speed also shifts
/// pitch; pitch-preserving speed arrives with the P4 custom engine.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_speed(speed: f64) {
    engine().set_speed(speed as f32);
}

/// 10-band graphic EQ, using ISO octave centers from 31 Hz to 16 kHz.
/// `gains` must contain exactly 10 dB values. Values are clamped by the engine
/// to -12..12 dB; `preamp_db` is clamped to -15..15 dB.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_eq(gains: Vec<f64>, preamp_db: f64) -> Result<(), String> {
    let gains: [f32; 10] = gains
        .into_iter()
        .map(|g| g as f32)
        .collect::<Vec<_>>()
        .try_into()
        .map_err(|_| "EQ requires exactly 10 band gains".to_string())?;
    engine().set_eq(gains, preamp_db as f32);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_position_ms() -> i64 {
    engine().position_ms() as i64
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_duration_ms() -> i64 {
    engine().duration_ms() as i64
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_is_playing() -> bool {
    engine().is_playing()
}

#[flutter_rust_bridge::frb(sync)]
pub fn audio_last_error() -> Option<String> {
    engine().last_error()
}
