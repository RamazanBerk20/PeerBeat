//! Real-time spectrum for the Now-Playing visualizer (desktop only).
//!
//! The audio thread publishes a sliding window of recent output samples via a
//! [`SpectrumTap`] in the DSP chain; the FRB layer polls [`compute`] at the UI
//! frame rate, which windows + FFTs the snapshot into a handful of log-spaced
//! magnitude bands (0..1). Cheap: one 1024-point FFT per poll, planner cached.

use rustfft::num_complex::Complex;
use rustfft::{Fft, FftPlanner};
use std::collections::VecDeque;
use std::f32::consts::PI;
use std::sync::{Arc, Mutex, OnceLock};

/// FFT window size (samples). Power of two for the planner.
const N: usize = 1024;
/// Publish a fresh window every this many samples (~bounded lock rate).
const HOP: usize = 256;

struct Snapshot {
    samples: Vec<f32>,
    #[allow(dead_code)]
    rate: u32,
}

static LATEST: Mutex<Option<Snapshot>> = Mutex::new(None);

fn fft() -> &'static Arc<dyn Fft<f32>> {
    static FFT: OnceLock<Arc<dyn Fft<f32>>> = OnceLock::new();
    FFT.get_or_init(|| FftPlanner::<f32>::new().plan_fft_forward(N))
}

/// Forget the last window so the visualizer settles to silence (on stop).
pub fn clear() {
    if let Ok(mut g) = LATEST.lock() {
        *g = None;
    }
}

/// Compute `bands` log-spaced magnitude bands (each ~0..1) from the latest
/// window. Returns all-zero when nothing has been published (idle / Android).
pub fn compute(bands: usize) -> Vec<f32> {
    if bands == 0 {
        return Vec::new();
    }
    let samples = match LATEST.lock() {
        Ok(g) => match g.as_ref() {
            Some(s) if s.samples.len() >= N => s.samples[s.samples.len() - N..].to_vec(),
            _ => return vec![0.0; bands],
        },
        Err(_) => return vec![0.0; bands],
    };

    // Hann-windowed real input → complex FFT.
    let mut buf: Vec<Complex<f32>> = samples
        .iter()
        .enumerate()
        .map(|(i, &x)| {
            let w = 0.5 - 0.5 * (2.0 * PI * i as f32 / (N as f32 - 1.0)).cos();
            Complex { re: x * w, im: 0.0 }
        })
        .collect();
    fft().process(&mut buf);

    // Magnitudes for bins 1..N/2 (skip DC).
    let half = N / 2;
    let mags: Vec<f32> = (1..half)
        .map(|i| (buf[i].re * buf[i].re + buf[i].im * buf[i].im).sqrt())
        .collect();
    let m = mags.len();

    let mut out = vec![0.0f32; bands];
    for (b, slot) in out.iter_mut().enumerate() {
        // Log-spaced bin ranges so low frequencies aren't crammed into one band.
        let lo = (m as f32).powf(b as f32 / bands as f32) as usize;
        let hi = (m as f32).powf((b + 1) as f32 / bands as f32) as usize;
        let lo = lo.min(m.saturating_sub(1));
        let hi = hi.clamp(lo + 1, m);
        let avg = mags[lo..hi].iter().copied().sum::<f32>() / (hi - lo) as f32;
        // Perceptual-ish scaling into 0..1 (sqrt compresses the dynamic range).
        *slot = (avg / (N as f32 * 0.25)).sqrt().clamp(0.0, 1.0);
    }
    out
}

/// A rodio `Source` pass-through that copies output samples into a sliding
/// window and periodically publishes it for [`compute`]. Audio is unchanged.
pub struct SpectrumTap<S> {
    inner: S,
    window: VecDeque<f32>,
    since_publish: usize,
}

impl<S> SpectrumTap<S> {
    pub fn new(inner: S) -> Self {
        Self {
            inner,
            window: VecDeque::with_capacity(N + 1),
            since_publish: 0,
        }
    }
}

impl<S: Iterator<Item = i16>> Iterator for SpectrumTap<S> {
    type Item = i16;
    fn next(&mut self) -> Option<i16> {
        let s = self.inner.next()?;
        self.window.push_back(s as f32 / 32768.0);
        while self.window.len() > N {
            self.window.pop_front();
        }
        self.since_publish += 1;
        if self.since_publish >= HOP && self.window.len() == N {
            self.since_publish = 0;
            if let Ok(mut g) = LATEST.lock() {
                *g = Some(Snapshot {
                    samples: self.window.iter().copied().collect(),
                    rate: 44_100,
                });
            }
        }
        Some(s)
    }
}

impl<S: rodio::Source<Item = i16>> rodio::Source for SpectrumTap<S> {
    fn current_frame_len(&self) -> Option<usize> {
        self.inner.current_frame_len()
    }
    fn channels(&self) -> u16 {
        self.inner.channels()
    }
    fn sample_rate(&self) -> u32 {
        self.inner.sample_rate()
    }
    fn total_duration(&self) -> Option<std::time::Duration> {
        self.inner.total_duration()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_spectrum_is_all_zero() {
        clear();
        let out = compute(16);
        assert_eq!(out.len(), 16);
        assert!(out.iter().all(|&v| v == 0.0));
    }

    #[test]
    fn a_tone_produces_a_nonzero_peak() {
        // Publish a full-scale mid sine directly into the window.
        let freq = 4000.0f32;
        let rate = 44_100.0f32;
        let window: Vec<f32> = (0..N)
            .map(|i| (2.0 * PI * freq * i as f32 / rate).sin())
            .collect();
        if let Ok(mut g) = LATEST.lock() {
            *g = Some(Snapshot {
                samples: window,
                rate: 44_100,
            });
        }
        let out = compute(24);
        let peak = out.iter().cloned().fold(0.0f32, f32::max);
        assert!(peak > 0.0, "a tone must light up at least one band");
        // The energy is not all in the very first (lowest) band.
        let argmax = out
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
            .unwrap()
            .0;
        assert!(
            argmax > 0,
            "a 4 kHz tone should not peak in the lowest band"
        );
        clear();
    }
}
