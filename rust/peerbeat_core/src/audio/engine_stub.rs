//! Android stub for [`AudioEngine`].
//!
//! Android playback goes through ExoPlayer on the Dart side, so the rodio/cpal
//! engine is never used here. Compiling it (and the Oboe C++ runtime it pulls in)
//! into the APK only bloated it and broke `dlopen` (`__cxa_pure_virtual`). This
//! stub keeps the FRB `audio_*` surface compiling and harmless: every transport
//! call is a no-op and state getters report "idle". The real engine lives in
//! `engine.rs`, compiled for every non-Android target.

/// No-op audio engine for Android (state is always idle).
#[derive(Default)]
pub struct AudioEngine;

impl AudioEngine {
    pub fn new() -> Self {
        Self
    }

    pub fn load(&self, _path: String) -> Result<(), String> {
        Err("native audio engine is not used on Android".to_string())
    }
    pub fn pause(&self) {}
    pub fn resume(&self) {}
    pub fn stop(&self) {}
    pub fn seek(&self, _ms: u64) -> Result<(), String> {
        Ok(())
    }
    pub fn set_volume(&self, _v: f32) {}
    pub fn set_speed(&self, _s: f32) {}
    pub fn set_crossfade(&self, _secs: f32) {}
    pub fn set_eq(&self, _gains: [f32; 10], _preamp_db: f32) {}
    pub fn set_output_device(&self, _device_id: Option<String>) -> Result<(), String> {
        Ok(())
    }
    pub fn set_stereo_width(&self, _width: f32) {}
    pub fn position_ms(&self) -> u64 {
        0
    }
    pub fn duration_ms(&self) -> u64 {
        0
    }
    pub fn is_playing(&self) -> bool {
        false
    }
    pub fn last_error(&self) -> Option<String> {
        None
    }
}
