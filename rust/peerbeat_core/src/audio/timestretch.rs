//! Pitch-preserving variable-speed playback via Signalsmith Stretch (`ssstretch`).
//!
//! [`TimeStretchSource`] is a rodio [`Source`](rodio::Source) adapter that
//! time-stretches the inner i16 stream by a live, shared factor while keeping
//! pitch constant. At **1.0× it bypasses the stretcher entirely** so normal
//! playback stays byte-for-byte unchanged and latency-free; only a speed other
//! than 1.0 routes audio through the phase-vocoder/WSOLA stretcher. The factor is
//! read once per output block from a cheaply-cloneable [`SpeedHandle`], so the UI
//! can change speed live.
//!
//! The Signalsmith dependency is **Linux/macOS only**: it's unused on Android
//! (ExoPlayer plays there) and doesn't compile under MSVC on Windows, so
//! [`TimeStretchSource`] and the `ssstretch` C++ dep are excluded on both — those
//! targets fall back to rodio's resampling speed in the engine. [`SpeedHandle`]
//! and the speed bounds stay cross-platform (pure Rust).

use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

/// Min/max supported speed (matches the UI presets; Signalsmith's sweet spot is
/// 0.75–1.5× but 0.5–2× stays usable).
pub const MIN_SPEED: f32 = 0.5;
pub const MAX_SPEED: f32 = 2.0;

/// Shared, cheaply-cloneable live playback speed (1.0 = normal). Lock-free: the
/// audio thread reads it once per output block.
#[derive(Clone)]
pub struct SpeedHandle(Arc<AtomicU32>);

impl SpeedHandle {
    pub fn new() -> Self {
        Self(Arc::new(AtomicU32::new(1.0f32.to_bits())))
    }

    /// Set the speed; clamped to the supported range.
    pub fn set(&self, speed: f32) {
        self.0.store(
            speed.clamp(MIN_SPEED, MAX_SPEED).to_bits(),
            Ordering::Release,
        );
    }

    pub fn get(&self) -> f32 {
        f32::from_bits(self.0.load(Ordering::Acquire))
    }
}

impl Default for SpeedHandle {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(not(any(target_os = "android", target_os = "windows")))]
pub use imp::TimeStretchSource;

#[cfg(not(any(target_os = "android", target_os = "windows")))]
mod imp {
    use super::{SpeedHandle, MAX_SPEED, MIN_SPEED};
    use rodio::Source;
    use ssstretch::Stretch;
    use std::collections::VecDeque;
    use std::time::Duration;

    /// Output frames produced per stretcher call. ~23 ms at 44.1 kHz — small
    /// enough that a speed change applies promptly, large enough to amortise the
    /// FFT cost.
    const BLOCK: usize = 1024;

    /// Wraps an i16 rodio source, time-stretching it by the shared [`SpeedHandle`]
    /// while preserving pitch. Channels and sample rate pass through unchanged.
    pub struct TimeStretchSource<S> {
        inner: S,
        handle: SpeedHandle,
        channels: usize,
        sample_rate: u32,
        stretch: Stretch,
        in_planar: Vec<Vec<f32>>,  // [channels][>= input frames this block]
        out_planar: Vec<Vec<f32>>, // [channels][>= output frames this block]
        ready: VecDeque<i16>,      // interleaved i16 ready to hand to the sink
        inner_done: bool,          // inner source reached EOF
        flushed: bool,             // stretcher tail drained (terminal in stretch mode)
        stretching: bool,          // stretcher currently engaged (speed != 1.0)
    }

    // SAFETY: `Stretch` wraps a Signalsmith C++ DSP object via a cxx `UniquePtr`,
    // which cxx conservatively marks `!Send`. That object holds only self-contained
    // FFT/overlap-add buffer state — no thread affinity, no shared mutable globals —
    // and `TimeStretchSource` owns it exclusively, touching it from a single thread
    // at a time (rodio moves the whole source onto the audio output thread, where
    // only that thread pulls from it). Transferring ownership across threads is
    // therefore sound, which is exactly what rodio's `Source: Send` bound requires.
    unsafe impl<S: Send> Send for TimeStretchSource<S> {}

    impl<S> TimeStretchSource<S>
    where
        S: Source<Item = i16>,
    {
        pub fn new(inner: S, handle: SpeedHandle) -> Self {
            let channels = inner.channels().max(1) as usize;
            let sample_rate = inner.sample_rate().max(1);
            let mut stretch = Stretch::new();
            stretch.preset_default(channels as i32, sample_rate as f32);
            stretch.set_transpose_factor(1.0, None); // pitch unchanged; we only stretch time
            Self {
                inner,
                handle,
                channels,
                sample_rate,
                stretch,
                in_planar: vec![Vec::new(); channels],
                out_planar: vec![vec![0.0; BLOCK]; channels],
                ready: VecDeque::new(),
                inner_done: false,
                flushed: false,
                stretching: false,
            }
        }

        /// Pull up to `frames` interleaved frames from the inner source into the
        /// planar input buffers as f32. Returns the frames actually read; sets
        /// `inner_done` on EOF.
        fn pull_planar(&mut self, frames: usize) -> usize {
            for ch in 0..self.channels {
                self.in_planar[ch].clear();
                self.in_planar[ch].resize(frames, 0.0);
            }
            let mut got = 0;
            'outer: for i in 0..frames {
                for ch in 0..self.channels {
                    match self.inner.next() {
                        Some(s) => self.in_planar[ch][i] = s as f32 / 32768.0,
                        None => {
                            self.inner_done = true;
                            break 'outer;
                        }
                    }
                }
                got = i + 1;
            }
            got
        }

        /// Interleave the first `frames` of each output channel into `ready` as i16.
        fn push_planar(&mut self, frames: usize) {
            for i in 0..frames {
                for ch in 0..self.channels {
                    let y = (self.out_planar[ch][i] * 32768.0).clamp(-32768.0, 32767.0);
                    self.ready.push_back(y as i16);
                }
            }
        }

        fn done(&self) -> bool {
            self.flushed || (self.inner_done && !self.stretching)
        }

        /// Produce one more block of output into `ready`.
        fn fill(&mut self) {
            if self.flushed {
                return;
            }
            let speed = self.handle.get().clamp(MIN_SPEED, MAX_SPEED);

            // 1.0×: bypass the stretcher → pristine, latency-free playback.
            if (speed - 1.0).abs() < 1e-3 {
                self.stretching = false;
                if self.inner_done {
                    return;
                }
                'block: for _ in 0..BLOCK {
                    for _ in 0..self.channels {
                        match self.inner.next() {
                            Some(s) => self.ready.push_back(s),
                            None => {
                                self.inner_done = true;
                                break 'block;
                            }
                        }
                    }
                }
                return;
            }

            // Engaging the stretcher after a passthrough span: clear stale internal
            // state so the transition doesn't smear earlier samples.
            if !self.stretching {
                self.stretch.reset();
                self.stretching = true;
            }

            if !self.inner_done {
                let want_in = (BLOCK as f32 * speed).round().max(1.0) as usize;
                let got = self.pull_planar(want_in);
                if got > 0 {
                    // Mid-stream we produce a full BLOCK; on the final short block,
                    // scale output to the fragment so it isn't over-stretched.
                    let out_n = if self.inner_done {
                        ((got as f32 / speed).round().max(1.0) as usize).min(BLOCK)
                    } else {
                        BLOCK
                    };
                    for ch in 0..self.channels {
                        self.out_planar[ch].clear();
                        self.out_planar[ch].resize(out_n, 0.0);
                    }
                    self.stretch.process_vec(
                        &self.in_planar,
                        got as i32,
                        &mut self.out_planar,
                        out_n as i32,
                    );
                    self.push_planar(out_n);
                }
            }

            // Drain the stretcher's internal latency tail once the input ends.
            if self.inner_done && !self.flushed {
                let tail = self.stretch.output_latency().max(0) as usize;
                if tail > 0 {
                    for ch in 0..self.channels {
                        self.out_planar[ch].clear();
                        self.out_planar[ch].resize(tail, 0.0);
                    }
                    self.stretch.flush_vec(&mut self.out_planar, tail as i32);
                    self.push_planar(tail);
                }
                self.flushed = true;
            }
        }
    }

    impl<S> Iterator for TimeStretchSource<S>
    where
        S: Source<Item = i16>,
    {
        type Item = i16;

        #[inline]
        fn next(&mut self) -> Option<i16> {
            if let Some(s) = self.ready.pop_front() {
                return Some(s);
            }
            while self.ready.is_empty() && !self.done() {
                self.fill();
            }
            self.ready.pop_front()
        }
    }

    impl<S> Source for TimeStretchSource<S>
    where
        S: Source<Item = i16>,
    {
        fn current_frame_len(&self) -> Option<usize> {
            None // continuous stream; channels/rate never change
        }
        fn channels(&self) -> u16 {
            self.channels as u16
        }
        fn sample_rate(&self) -> u32 {
            self.sample_rate
        }
        fn total_duration(&self) -> Option<Duration> {
            // Content duration is unchanged by speed (the scrubber shows song time).
            self.inner.total_duration()
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use rodio::buffer::SamplesBuffer;

        fn mono(n: usize) -> SamplesBuffer<i16> {
            SamplesBuffer::new(1, 44100, vec![1000i16; n])
        }

        #[test]
        fn passthrough_at_1x_is_lossless_and_same_length() {
            let src = TimeStretchSource::new(mono(5000), SpeedHandle::new());
            let out: Vec<i16> = src.collect();
            assert_eq!(out.len(), 5000, "1.0x must neither add nor drop samples");
            assert!(out.iter().all(|&s| s == 1000), "1.0x must be bit-exact");
        }

        #[test]
        fn faster_yields_proportionally_fewer_samples() {
            let h = SpeedHandle::new();
            h.set(2.0);
            let out: Vec<i16> = TimeStretchSource::new(mono(44100), h).collect();
            let ratio = out.len() as f32 / 44100.0;
            assert!(
                (ratio - 0.5).abs() < 0.1,
                "2.0x should ~halve length, got {ratio}"
            );
        }

        #[test]
        fn slower_yields_proportionally_more_samples() {
            let h = SpeedHandle::new();
            h.set(0.5);
            let out: Vec<i16> = TimeStretchSource::new(mono(22050), h).collect();
            let ratio = out.len() as f32 / 22050.0;
            assert!(
                (ratio - 2.0).abs() < 0.2,
                "0.5x should ~double length, got {ratio}"
            );
        }

        #[test]
        fn channels_and_rate_are_preserved() {
            let src = TimeStretchSource::new(
                SamplesBuffer::new(2, 48000, vec![0i16; 400]),
                SpeedHandle::new(),
            );
            assert_eq!(src.channels(), 2);
            assert_eq!(src.sample_rate(), 48000);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn speed_handle_clamps_to_supported_range() {
        let h = SpeedHandle::new();
        h.set(9.0);
        assert_eq!(h.get(), MAX_SPEED);
        h.set(0.01);
        assert_eq!(h.get(), MIN_SPEED);
    }
}
