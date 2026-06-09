//! FRB audio transport API (desktop). Holds the engine in a process-wide
//! `OnceLock`, created lazily on first use. Calls are `sync` (they only push a
//! command or read an atomic) so the UI gets immediate, low-latency control.

use crate::audio::AudioEngine;
use std::sync::OnceLock;

static ENGINE: OnceLock<AudioEngine> = OnceLock::new();

fn engine() -> &'static AudioEngine {
    ENGINE.get_or_init(|| {
        silence_alsa();
        AudioEngine::new()
    })
}

/// Install a no-op ALSA error handler so libasound's `dmix`/`jack`/`/dev/dsp`
/// probe messages (printed to stderr by cpal during device enumeration / stream
/// open) don't spam the logs. Linux-only; a no-op elsewhere. Idempotent.
#[cfg(target_os = "linux")]
fn silence_alsa() {
    use std::os::raw::{c_char, c_int};
    use std::sync::Once;
    static ONCE: Once = Once::new();
    // ALSA's handler is variadic; we register a non-variadic no-op and let it
    // ignore the trailing args (safe — it reads none).
    type Handler = extern "C" fn(*const c_char, c_int, *const c_char, c_int, *const c_char);
    #[link(name = "asound")]
    extern "C" {
        fn snd_lib_error_set_handler(handler: Handler) -> c_int;
    }
    extern "C" fn quiet(
        _file: *const c_char,
        _line: c_int,
        _func: *const c_char,
        _err: c_int,
        _fmt: *const c_char,
    ) {
    }
    ONCE.call_once(|| unsafe {
        snd_lib_error_set_handler(quiet);
    });
}

#[cfg(not(target_os = "linux"))]
fn silence_alsa() {}

pub struct OutputDeviceRow {
    pub id: String,
    pub name: String,
    pub is_default: bool,
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

/// Playback speed; the engine clamps to 0.5–2.0 (1.0 = normal). On Linux/macOS
/// this is pitch-preserving via Signalsmith Stretch; on Windows (MSVC) the
/// stretch stage is disabled and speed falls back to rodio's pitch-shifting
/// resample.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_speed(speed: f64) {
    engine().set_speed(speed as f32);
}

/// Crossfade duration between tracks, in seconds (0–12; 0 disables — the default).
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_crossfade(secs: f64) {
    engine().set_crossfade(secs as f32);
}

/// Latest Now-Playing visualizer spectrum: `bands` log-spaced magnitudes, each
/// roughly 0..1. Cheap (one cached 1024-pt FFT); poll at the UI frame rate.
/// All-zero when idle, and on Android (no desktop engine).
#[flutter_rust_bridge::frb(sync)]
pub fn audio_spectrum(bands: u32) -> Vec<f32> {
    crate::audio::spectrum_bands(bands as usize)
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

#[cfg(target_os = "android")]
pub fn audio_output_devices() -> Result<Vec<OutputDeviceRow>, String> {
    // Output routing is OS-controlled on Android (and the rodio/cpal engine isn't
    // compiled there); expose only the system default.
    Ok(vec![OutputDeviceRow {
        id: "default".to_string(),
        name: "System default".to_string(),
        is_default: true,
    }])
}

#[cfg(not(target_os = "android"))]
pub fn audio_output_devices() -> Result<Vec<OutputDeviceRow>, String> {
    use rodio::cpal::traits::{DeviceTrait, HostTrait};

    silence_alsa(); // quiet libasound's probe spam during enumeration
    let host = rodio::cpal::default_host();
    let default_name = host.default_output_device().and_then(|d| d.name().ok());
    let mut rows = vec![OutputDeviceRow {
        id: "default".to_string(),
        name: "System default".to_string(),
        is_default: true,
    }];
    for (index, device) in host
        .output_devices()
        .map_err(|e| format!("cannot list output devices: {e}"))?
        .enumerate()
    {
        let name = device
            .name()
            .unwrap_or_else(|_| format!("Output device {}", index + 1));
        rows.push(OutputDeviceRow {
            id: format!("device:{index}"),
            is_default: default_name.as_deref() == Some(name.as_str()),
            name,
        });
    }
    Ok(rows)
}

pub fn audio_set_output_device(device_id: Option<String>) -> Result<(), String> {
    engine().set_output_device(device_id)
}

/// Stereo width: 0.0 = mono, 1.0 = unchanged, 2.0 = widened.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_stereo_width(width: f64) {
    engine().set_stereo_width(width as f32);
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
