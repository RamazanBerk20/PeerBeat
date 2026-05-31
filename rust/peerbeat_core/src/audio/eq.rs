//! 10-band graphic equalizer: a cascade of RBJ peaking biquads applied as a
//! rodio [`Source`] adapter. Gains are shared via an [`EqHandle`] so the UI can
//! change them live; each playing source recomputes coefficients for its own
//! sample rate when the generation counter bumps (one atomic load per frame,
//! a mutex only when something actually changed).

use rodio::Source;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

/// ISO octave centre frequencies for the 10 bands (Hz).
pub const BANDS_HZ: [f32; 10] = [
    31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];
/// Q for ~1-octave-wide bands.
const Q: f32 = 1.414;

/// Transposed-Direct-Form-II peaking biquad coefficients (a0-normalized).
#[derive(Clone, Copy)]
pub struct Biquad {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
}

impl Biquad {
    pub const IDENTITY: Biquad = Biquad {
        b0: 1.0,
        b1: 0.0,
        b2: 0.0,
        a1: 0.0,
        a2: 0.0,
    };

    /// RBJ cookbook peaking EQ at `freq` for sample rate `fs` and `gain_db`.
    pub fn peaking(freq: f32, fs: f32, gain_db: f32) -> Self {
        if gain_db.abs() < 1e-3 || freq >= fs * 0.5 {
            return Biquad::IDENTITY;
        }
        let a = 10f32.powf(gain_db / 40.0);
        let w0 = 2.0 * std::f32::consts::PI * freq / fs;
        let (sin, cos) = w0.sin_cos();
        let alpha = sin / (2.0 * Q);
        let a0 = 1.0 + alpha / a;
        Biquad {
            b0: (1.0 + alpha * a) / a0,
            b1: (-2.0 * cos) / a0,
            b2: (1.0 - alpha * a) / a0,
            a1: (-2.0 * cos) / a0,
            a2: (1.0 - alpha / a) / a0,
        }
    }
}

/// Per-band filter memory (one per channel).
#[derive(Clone, Copy, Default)]
struct State {
    s1: f32,
    s2: f32,
}

impl State {
    #[inline]
    fn process(&mut self, bq: &Biquad, x: f32) -> f32 {
        let y = bq.b0 * x + self.s1;
        self.s1 = bq.b1 * x - bq.a1 * y + self.s2;
        self.s2 = bq.b2 * x - bq.a2 * y;
        y
    }
}

/// Compute the 10 band coefficients for a given sample rate.
pub fn compute_coeffs(gains_db: &[f32; 10], fs: f32) -> [Biquad; 10] {
    std::array::from_fn(|i| Biquad::peaking(BANDS_HZ[i], fs, gains_db[i]))
}

#[derive(Clone, Copy)]
struct EqSettings {
    gains: [f32; 10],
    preamp_db: f32,
}

/// Shared, cheaply-cloneable handle controlling the live EQ.
#[derive(Clone)]
pub struct EqHandle {
    settings: Arc<Mutex<EqSettings>>,
    generation: Arc<AtomicU64>,
}

impl EqHandle {
    pub fn new() -> Self {
        Self {
            settings: Arc::new(Mutex::new(EqSettings {
                gains: [0.0; 10],
                preamp_db: 0.0,
            })),
            generation: Arc::new(AtomicU64::new(0)),
        }
    }

    /// Update the band gains (dB) and pre-amp (dB); takes effect on the next
    /// audio frame of any playing source.
    pub fn set(&self, gains: [f32; 10], preamp_db: f32) {
        if let Ok(mut s) = self.settings.lock() {
            s.gains = gains;
            s.preamp_db = preamp_db;
        }
        self.generation.fetch_add(1, Ordering::Release);
    }

    fn read(&self) -> EqSettings {
        self.settings.lock().map(|s| *s).unwrap_or(EqSettings {
            gains: [0.0; 10],
            preamp_db: 0.0,
        })
    }
}

impl Default for EqHandle {
    fn default() -> Self {
        Self::new()
    }
}

/// Wraps an i16 rodio source, applying the shared EQ in f32 and emitting i16.
pub struct EqSource<S> {
    inner: S,
    handle: EqHandle,
    fs: f32,
    channels: u16,
    ch: usize,
    states: Vec<[State; 10]>,
    coeffs: [Biquad; 10],
    preamp: f32, // linear
    enabled: bool,
    local_gen: u64,
}

impl<S> EqSource<S>
where
    S: Source<Item = i16>,
{
    pub fn new(inner: S, handle: EqHandle) -> Self {
        let fs = inner.sample_rate() as f32;
        let channels = inner.channels().max(1);
        let mut me = Self {
            states: vec![[State::default(); 10]; channels as usize],
            inner,
            handle,
            fs,
            channels,
            ch: 0,
            coeffs: [Biquad::IDENTITY; 10],
            preamp: 1.0,
            enabled: false,
            local_gen: u64::MAX, // force initial refresh
        };
        me.refresh();
        me
    }

    #[inline]
    fn refresh(&mut self) {
        let g = self.handle.generation.load(Ordering::Acquire);
        if g == self.local_gen {
            return;
        }
        let s = self.handle.read();
        self.coeffs = compute_coeffs(&s.gains, self.fs);
        self.preamp = 10f32.powf(s.preamp_db / 20.0);
        self.enabled = s.preamp_db.abs() > 1e-3 || s.gains.iter().any(|g| g.abs() > 1e-3);
        self.local_gen = g;
    }
}

impl<S> Iterator for EqSource<S>
where
    S: Source<Item = i16>,
{
    type Item = i16;

    #[inline]
    fn next(&mut self) -> Option<i16> {
        let x = self.inner.next()?;
        if self.ch == 0 {
            self.refresh(); // once per interleaved frame
        }
        let out = if self.enabled {
            let mut y = x as f32 / 32768.0;
            let st = &mut self.states[self.ch];
            for (band, coeff) in self.coeffs.iter().enumerate() {
                y = st[band].process(coeff, y);
            }
            y *= self.preamp;
            (y * 32768.0).clamp(-32768.0, 32767.0) as i16
        } else {
            x
        };
        self.ch = (self.ch + 1) % self.channels as usize;
        Some(out)
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl<S> Source for EqSource<S>
where
    S: Source<Item = i16>,
{
    fn current_frame_len(&self) -> Option<usize> {
        self.inner.current_frame_len()
    }
    fn channels(&self) -> u16 {
        self.channels
    }
    fn sample_rate(&self) -> u32 {
        self.fs as u32
    }
    fn total_duration(&self) -> Option<Duration> {
        self.inner.total_duration()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flat_gains_are_identity() {
        let c = compute_coeffs(&[0.0; 10], 44100.0);
        for b in &c {
            assert_eq!(b.b0, 1.0);
            assert_eq!(b.b1, 0.0);
        }
    }

    #[test]
    fn peaking_is_stable_and_nontrivial() {
        // A boosted band must produce real (non-identity) coefficients with a
        // stable denominator (|a2| < 1 ⇒ poles inside the unit circle).
        let bq = Biquad::peaking(1000.0, 44100.0, 9.0);
        assert!((bq.b0 - 1.0).abs() > 1e-3);
        assert!(bq.a2.abs() < 1.0, "unstable pole: a2={}", bq.a2);
    }

    #[test]
    fn band_above_nyquist_is_identity() {
        // 16 kHz band at 22.05 kHz Nyquist-limited rate must not blow up.
        let bq = Biquad::peaking(16000.0, 8000.0, 12.0);
        assert_eq!(bq.b0, 1.0);
    }

    #[test]
    fn dc_unity_when_flat() {
        // Feeding a constant through flat EQ returns ~it (after settling).
        let mut st = State::default();
        let bq = Biquad::IDENTITY;
        let mut y = 0.0;
        for _ in 0..8 {
            y = st.process(&bq, 0.5);
        }
        assert!((y - 0.5).abs() < 1e-6);
    }
}
