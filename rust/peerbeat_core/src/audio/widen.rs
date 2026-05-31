//! Optional stereo widening via mid/side gain.

use rodio::Source;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

#[derive(Clone)]
pub struct StereoWidenHandle {
    width: Arc<Mutex<f32>>,
    generation: Arc<AtomicU64>,
}

impl StereoWidenHandle {
    pub fn new() -> Self {
        Self {
            width: Arc::new(Mutex::new(1.0)),
            generation: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn set(&self, width: f32) {
        if let Ok(mut w) = self.width.lock() {
            *w = width.clamp(0.0, 2.0);
        }
        self.generation.fetch_add(1, Ordering::Release);
    }

    fn read(&self) -> f32 {
        self.width.lock().map(|w| *w).unwrap_or(1.0)
    }
}

impl Default for StereoWidenHandle {
    fn default() -> Self {
        Self::new()
    }
}

pub struct StereoWidenSource<S> {
    inner: S,
    handle: StereoWidenHandle,
    channels: u16,
    width: f32,
    local_gen: u64,
    pending_right: Option<i16>,
}

impl<S> StereoWidenSource<S>
where
    S: Source<Item = i16>,
{
    pub fn new(inner: S, handle: StereoWidenHandle) -> Self {
        let channels = inner.channels();
        let mut me = Self {
            inner,
            handle,
            channels,
            width: 1.0,
            local_gen: u64::MAX,
            pending_right: None,
        };
        me.refresh();
        me
    }

    fn refresh(&mut self) {
        let g = self.handle.generation.load(Ordering::Acquire);
        if g == self.local_gen {
            return;
        }
        self.width = self.handle.read();
        self.local_gen = g;
    }
}

impl<S> Iterator for StereoWidenSource<S>
where
    S: Source<Item = i16>,
{
    type Item = i16;

    fn next(&mut self) -> Option<Self::Item> {
        if self.channels != 2 {
            return self.inner.next();
        }
        if let Some(r) = self.pending_right.take() {
            return Some(r);
        }
        self.refresh();
        let l = self.inner.next()?;
        let r = self.inner.next()?;
        if (self.width - 1.0).abs() < 1e-3 {
            self.pending_right = Some(r);
            return Some(l);
        }
        let lf = l as f32 / 32768.0;
        let rf = r as f32 / 32768.0;
        let mid = (lf + rf) * 0.5;
        let side = (lf - rf) * 0.5 * self.width;
        let out_l = ((mid + side).clamp(-1.0, 1.0) * 32768.0) as i16;
        let out_r = ((mid - side).clamp(-1.0, 1.0) * 32768.0) as i16;
        self.pending_right = Some(out_r);
        Some(out_l)
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl<S> Source for StereoWidenSource<S>
where
    S: Source<Item = i16>,
{
    fn current_frame_len(&self) -> Option<usize> {
        self.inner
            .current_frame_len()
            .map(|n| n + usize::from(self.pending_right.is_some()))
    }
    fn channels(&self) -> u16 {
        self.channels
    }
    fn sample_rate(&self) -> u32 {
        self.inner.sample_rate()
    }
    fn total_duration(&self) -> Option<Duration> {
        self.inner.total_duration()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rodio::buffer::SamplesBuffer;

    #[test]
    fn width_zero_collapses_to_mono() {
        let handle = StereoWidenHandle::new();
        handle.set(0.0);
        let src = SamplesBuffer::new(2, 44_100, vec![10000i16, -10000i16]);
        let out: Vec<i16> = StereoWidenSource::new(src, handle).collect();
        assert_eq!(out, vec![0, 0]);
    }

    #[test]
    fn width_one_is_identity() {
        let handle = StereoWidenHandle::new();
        let src = SamplesBuffer::new(2, 44_100, vec![10000i16, -10000i16]);
        let out: Vec<i16> = StereoWidenSource::new(src, handle).collect();
        assert_eq!(out, vec![10000, -10000]);
    }
}
