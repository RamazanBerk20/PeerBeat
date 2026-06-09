//! Desktop audio engine (interim) built on `rodio`.
//!
//! rodio's stream/sink are `!Send`, so the engine owns them on a dedicated
//! thread and is driven by a command channel; playback state is published via
//! shared atomics the FRB layer reads. This delivers M1 transport
//! (load/play/pause/seek/volume + position). The DSP graph (10-band EQ,
//! crossfade, ReplayGain, pitch-preserving speed) is the M2 custom
//! symphonia→cpal path that replaces rodio here.

use std::io::BufReader;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use super::eq::{EqHandle, EqSource};
#[cfg(not(target_os = "windows"))]
use super::timestretch::TimeStretchSource;
use super::timestretch::{SpeedHandle, MAX_SPEED, MIN_SPEED};
use super::widen::{StereoWidenHandle, StereoWidenSource};

const END_SEEK_EPSILON: Duration = Duration::from_millis(250);

enum Cmd {
    Load(String, Sender<Result<(), String>>),
    Resume,
    Pause,
    Stop,
    Seek(u64, Sender<Result<(), String>>),
    Volume(f32),
    Speed(f32),
    Eq([f32; 10], f32),
    Device(Option<String>, Sender<Result<(), String>>),
    StereoWidth(f32),
    Crossfade(f32),
}

#[derive(Default)]
struct Shared {
    position_ms: AtomicU64,
    duration_ms: AtomicU64,
    playing: AtomicBool,
    ended: Arc<AtomicBool>,
}

/// Handle to the audio thread. `Send + Sync` (only a channel sender + atomics),
/// so it lives in a process-wide `OnceLock`.
pub struct AudioEngine {
    tx: Mutex<Sender<Cmd>>,
    shared: Arc<Shared>,
    last_error: Arc<Mutex<Option<String>>>,
}

impl AudioEngine {
    pub fn new() -> Self {
        let shared = Arc::new(Shared::default());
        let last_error = Arc::new(Mutex::new(None));
        let tx = spawn_worker(shared.clone(), last_error.clone());
        Self {
            tx: Mutex::new(tx),
            shared,
            last_error,
        }
    }

    pub fn load(&self, path: String) -> Result<(), String> {
        let mut last_failure = None;
        for attempt in 0..2 {
            let (reply_tx, reply_rx) = channel();
            let send_result = self
                .tx
                .lock()
                .map_err(|_| "audio worker lock poisoned".to_string())?
                .send(Cmd::Load(path.clone(), reply_tx));
            if let Err(e) = send_result {
                let msg = format!("audio worker unavailable: {e}");
                set_last_error(&self.last_error, Some(msg.clone()));
                last_failure = Some(msg);
                self.restart_worker()?;
                continue;
            }

            match reply_rx.recv() {
                Ok(result) => return result,
                Err(e) => {
                    let root = self.last_error().unwrap_or_else(|| e.to_string());
                    let msg = format!("audio worker closed before loading: {root}");
                    set_last_error(&self.last_error, Some(msg.clone()));
                    last_failure = Some(msg);
                    if attempt == 0 {
                        self.restart_worker()?;
                    }
                }
            }
        }
        Err(last_failure.unwrap_or_else(|| "audio worker closed before loading".to_string()))
    }
    pub fn pause(&self) {
        let _ = self.send(Cmd::Pause);
    }
    pub fn resume(&self) {
        let _ = self.send(Cmd::Resume);
    }
    pub fn stop(&self) {
        let _ = self.send(Cmd::Stop);
    }
    pub fn seek(&self, ms: u64) -> Result<(), String> {
        let (reply_tx, reply_rx) = channel();
        self.send(Cmd::Seek(ms, reply_tx))?;
        reply_rx
            .recv()
            .map_err(|e| format!("audio worker closed before seeking: {e}"))?
    }
    pub fn set_volume(&self, v: f32) {
        let _ = self.send(Cmd::Volume(v.clamp(0.0, 2.0)));
    }
    pub fn set_speed(&self, s: f32) {
        // Pitch-preserving time-stretch is usable across 0.5–2× (matches the UI
        // presets); outside that range Signalsmith Stretch degrades.
        let _ = self.send(Cmd::Speed(s.clamp(MIN_SPEED, MAX_SPEED)));
    }
    pub fn set_crossfade(&self, secs: f32) {
        let _ = self.send(Cmd::Crossfade(secs.clamp(0.0, 12.0)));
    }
    pub fn set_eq(&self, gains: [f32; 10], preamp_db: f32) {
        let gains = gains.map(|g| g.clamp(-12.0, 12.0));
        let _ = self.send(Cmd::Eq(gains, preamp_db.clamp(-15.0, 15.0)));
    }
    pub fn set_output_device(&self, device_id: Option<String>) -> Result<(), String> {
        let (reply_tx, reply_rx) = channel();
        self.send(Cmd::Device(device_id, reply_tx))?;
        reply_rx
            .recv()
            .map_err(|e| format!("audio worker closed before switching output device: {e}"))?
    }
    pub fn set_stereo_width(&self, width: f32) {
        let _ = self.send(Cmd::StereoWidth(width.clamp(0.0, 2.0)));
    }
    pub fn position_ms(&self) -> u64 {
        self.shared.position_ms.load(Ordering::Relaxed)
    }
    pub fn duration_ms(&self) -> u64 {
        self.shared.duration_ms.load(Ordering::Relaxed)
    }
    pub fn is_playing(&self) -> bool {
        self.shared.playing.load(Ordering::Relaxed)
    }
    pub fn last_error(&self) -> Option<String> {
        self.last_error.lock().ok().and_then(|e| e.clone())
    }

    fn send(&self, cmd: Cmd) -> Result<(), String> {
        match self
            .tx
            .lock()
            .map_err(|_| "audio worker lock poisoned".to_string())?
            .send(cmd)
        {
            Ok(()) => Ok(()),
            Err(e) => {
                let msg = format!("audio worker unavailable: {e}");
                set_last_error(&self.last_error, Some(msg.clone()));
                let _ = self.restart_worker();
                Err(msg)
            }
        }
    }

    fn restart_worker(&self) -> Result<(), String> {
        let tx = spawn_worker(self.shared.clone(), self.last_error.clone());
        *self
            .tx
            .lock()
            .map_err(|_| "audio worker lock poisoned".to_string())? = tx;
        Ok(())
    }
}

impl Default for AudioEngine {
    fn default() -> Self {
        Self::new()
    }
}

fn set_last_error(last_error: &Arc<Mutex<Option<String>>>, msg: Option<String>) {
    if let Ok(mut e) = last_error.lock() {
        *e = msg;
    }
}

fn panic_detail(payload: Box<dyn std::any::Any + Send>) -> String {
    payload
        .downcast_ref::<&str>()
        .map(|s| (*s).to_string())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "unknown panic".to_string())
}

fn clamp_seek_position(pos: Duration, total_duration: Option<Duration>) -> Duration {
    match total_duration {
        Some(duration) if duration > END_SEEK_EPSILON && pos >= duration - END_SEEK_EPSILON => {
            duration - END_SEEK_EPSILON
        }
        Some(duration) if pos > duration => duration,
        _ => pos,
    }
}

struct SymphoniaFileSource {
    format: Box<dyn symphonia::core::formats::FormatReader>,
    decoder: Box<dyn symphonia::core::codecs::Decoder>,
    track_id: u32,
    buffer: Vec<i16>,
    pos: usize,
    channels: u16,
    sample_rate: u32,
    total_duration: Option<Duration>,
    finished: bool,
}

impl SymphoniaFileSource {
    fn open(path: &str) -> Result<Self, String> {
        use symphonia::core::audio::SignalSpec;
        use symphonia::core::formats::FormatOptions;
        use symphonia::core::io::{MediaSourceStream, MediaSourceStreamOptions};
        use symphonia::core::meta::MetadataOptions;
        use symphonia::core::probe::Hint;

        let file = std::fs::File::open(path)
            .map_err(|e| format!("cannot open audio file '{path}': {e}"))?;
        let mss = MediaSourceStream::new(Box::new(file), MediaSourceStreamOptions::default());
        let mut hint = Hint::new();
        if let Some(ext) = std::path::Path::new(path)
            .extension()
            .and_then(|s| s.to_str())
        {
            hint.with_extension(ext);
        }
        let format_opts = FormatOptions {
            // Trim encoder delay/padding so consecutive compressed tracks
            // (MP3/AAC) play without the inserted silence — the usual audible gap.
            enable_gapless: true,
            ..Default::default()
        };
        let metadata_opts = MetadataOptions::default();
        let probed = symphonia::default::get_probe()
            .format(&hint, mss, &format_opts, &metadata_opts)
            .map_err(|e| format!("cannot probe audio file '{path}': {e}"))?;
        let format = probed.format;
        let track = format
            .default_track()
            .or_else(|| format.tracks().first())
            .ok_or_else(|| format!("no audio streams in '{path}'"))?;
        let track_id = track.id;
        let params = track.codec_params.clone();
        let decoder = symphonia::default::get_codecs()
            .make(&params, &Default::default())
            .map_err(|e| format!("cannot decode audio file '{path}': {e}"))?;
        let SignalSpec { rate, channels } = params
            .sample_rate
            .zip(params.channels)
            .map(|(rate, channels)| SignalSpec { rate, channels })
            .unwrap_or_else(|| {
                SignalSpec::new(
                    48_000,
                    symphonia::core::audio::Channels::FRONT_LEFT
                        | symphonia::core::audio::Channels::FRONT_RIGHT,
                )
            });
        let total_duration = params.time_base.zip(params.n_frames).map(|(base, frames)| {
            let t = base.calc_time(frames);
            Duration::from_secs(t.seconds) + Duration::from_secs_f64(t.frac)
        });

        Ok(Self {
            format,
            decoder,
            track_id,
            buffer: Vec::new(),
            pos: 0,
            channels: channels.count() as u16,
            sample_rate: rate,
            total_duration,
            finished: false,
        })
    }

    fn refill(&mut self) -> Option<i16> {
        use symphonia::core::audio::SampleBuffer;
        use symphonia::core::errors::Error;

        while !self.finished {
            let packet = match self.format.next_packet() {
                Ok(packet) => packet,
                Err(Error::IoError(_)) => {
                    self.finished = true;
                    return None;
                }
                Err(_) => continue,
            };
            if packet.track_id() != self.track_id {
                continue;
            }
            let decoded = match self.decoder.decode(&packet) {
                Ok(decoded) => decoded,
                Err(Error::DecodeError(_)) => continue,
                Err(_) => {
                    self.finished = true;
                    return None;
                }
            };
            let spec = *decoded.spec();
            let mut samples = SampleBuffer::<i16>::new(decoded.capacity() as u64, spec);
            samples.copy_interleaved_ref(decoded);
            self.buffer.clear();
            self.buffer.extend_from_slice(samples.samples());
            self.pos = 0;
            if let Some(sample) = self.buffer.first().copied() {
                self.pos = 1;
                return Some(sample);
            }
        }
        None
    }
}

impl Iterator for SymphoniaFileSource {
    type Item = i16;

    fn next(&mut self) -> Option<Self::Item> {
        if self.pos < self.buffer.len() {
            let sample = self.buffer[self.pos];
            self.pos += 1;
            Some(sample)
        } else {
            self.refill()
        }
    }
}

impl rodio::Source for SymphoniaFileSource {
    fn current_frame_len(&self) -> Option<usize> {
        Some(self.buffer.len().saturating_sub(self.pos))
    }

    fn channels(&self) -> u16 {
        self.channels
    }

    fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    fn total_duration(&self) -> Option<Duration> {
        self.total_duration
    }

    fn try_seek(&mut self, pos: Duration) -> Result<(), rodio::source::SeekError> {
        use symphonia::core::formats::{SeekMode, SeekTo};

        let seek_pos = clamp_seek_position(pos, self.total_duration);
        self.format
            .seek(
                SeekMode::Accurate,
                SeekTo::Time {
                    time: seek_pos.as_secs_f64().into(),
                    track_id: Some(self.track_id),
                },
            )
            .map_err(|e| {
                rodio::source::SeekError::Other(Box::new(std::io::Error::other(format!("{e:?}"))))
            })?;
        self.decoder.reset();
        self.buffer.clear();
        self.pos = 0;
        self.finished = false;
        Ok(())
    }
}

fn open_source(path: &str) -> Result<Box<dyn rodio::Source<Item = i16> + Send>, String> {
    use rodio::Decoder;

    let ext = std::path::Path::new(path)
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();
    match ext.as_str() {
        "aac" | "m4a" | "m4b" | "m4p" | "m4r" | "m4v" | "mov" | "mp4" => {
            Ok(Box::new(SymphoniaFileSource::open(path)?))
        }
        "mp3" | "flac" | "ogg" | "oga" | "wav" => {
            let file = std::fs::File::open(path)
                .map_err(|e| format!("cannot open audio file '{path}': {e}"))?;
            let dec = catch_unwind(AssertUnwindSafe(|| {
                let reader = BufReader::new(file);
                match ext.as_str() {
                    "mp3" => Decoder::new_mp3(reader),
                    "flac" => Decoder::new_flac(reader),
                    "ogg" | "oga" => Decoder::new_vorbis(reader),
                    _ => Decoder::new_wav(reader),
                }
            }))
            .map_err(|payload| {
                let detail = panic_detail(payload);
                format!("decoder crashed for audio file '{path}': {detail}")
            })?
            .map_err(|e| format!("cannot decode audio file '{path}': {e}"))?;
            Ok(Box::new(dec))
        }
        _ => {
            // Unknown/missing extension (e.g. a LAN stream cached as ".audio"):
            // probe the container by content with symphonia rather than rodio's
            // generic `Decoder::new`, which panics ("unreachable: Seek errors
            // should not occur during initialization") on some MP3/streamed inputs.
            Ok(Box::new(SymphoniaFileSource::open(path)?))
        }
    }
}

#[cfg(not(target_os = "windows"))]
fn with_dsp(
    source: Box<dyn rodio::Source<Item = i16> + Send>,
    eq: EqHandle,
    widen: StereoWidenHandle,
    speed: SpeedHandle,
    ended: Arc<AtomicBool>,
) -> Box<dyn rodio::Source<Item = i16> + Send> {
    // EQ → stereo widen → pitch-preserving time-stretch → end-notify. The
    // stretcher is a no-op (pure passthrough) while speed == 1.0.
    Box::new(EndNotifySource::new(
        TimeStretchSource::new(
            StereoWidenSource::new(EqSource::new(source, eq), widen),
            speed,
        ),
        ended,
    ))
}

// Windows: Signalsmith Stretch's cxx bridge doesn't compile under MSVC, so there's
// no time-stretch stage; variable speed falls back to rodio's resampling
// `sink.set_speed` (see `engage_speed`). The `speed` handle is ignored here.
#[cfg(target_os = "windows")]
fn with_dsp(
    source: Box<dyn rodio::Source<Item = i16> + Send>,
    eq: EqHandle,
    widen: StereoWidenHandle,
    _speed: SpeedHandle,
    ended: Arc<AtomicBool>,
) -> Box<dyn rodio::Source<Item = i16> + Send> {
    Box::new(EndNotifySource::new(
        StereoWidenSource::new(EqSource::new(source, eq), widen),
        ended,
    ))
}

// Apply the current speed to a freshly-created sink / on a speed change. On
// platforms with the time-stretch stage the sink stays at 1.0× and the live
// `SpeedHandle` drives speed; on Windows (no stretcher) we use rodio's pitch-
// shifting `set_speed` directly.
#[cfg(not(target_os = "windows"))]
fn engage_speed(_sink: &rodio::Sink, speed: f32, handle: &SpeedHandle) {
    handle.set(speed);
}
#[cfg(target_os = "windows")]
fn engage_speed(sink: &rodio::Sink, speed: f32, _handle: &SpeedHandle) {
    sink.set_speed(speed);
}

fn open_seeked_source(
    path: &str,
    target: Duration,
    eq: EqHandle,
    widen: StereoWidenHandle,
    speed: SpeedHandle,
    ended: Arc<AtomicBool>,
) -> Result<Box<dyn rodio::Source<Item = i16> + Send>, String> {
    use rodio::Source;

    let mut source = open_source(path)?;
    if source.try_seek(target).is_ok() {
        return Ok(with_dsp(source, eq, widen, speed, ended));
    }
    // The format can't seek in place (e.g. symphonia `Unseekable` on some
    // webm/ogg, or a seektable-less FLAC). The only fallback is to decode from
    // the start and discard up to `target` — but that is eager and synchronous,
    // so a large jump would peg the CPU and freeze playback. Do it only for short
    // targets (resume bookmarks, small scrubs); otherwise report a clean error so
    // the caller keeps playing from where it was.
    const MAX_SKIP: Duration = Duration::from_secs(10);
    if target <= MAX_SKIP {
        let fresh = open_source(path)?;
        Ok(with_dsp(
            Box::new(fresh.skip_duration(target)),
            eq,
            widen,
            speed,
            ended,
        ))
    } else {
        Err("this track's format doesn't support seeking that far".to_string())
    }
}

struct EndNotifySource<S> {
    inner: S,
    ended: Arc<AtomicBool>,
}

impl<S> EndNotifySource<S>
where
    S: rodio::Source<Item = i16>,
{
    fn new(inner: S, ended: Arc<AtomicBool>) -> Self {
        Self { inner, ended }
    }
}

impl<S> Iterator for EndNotifySource<S>
where
    S: rodio::Source<Item = i16>,
{
    type Item = i16;

    fn next(&mut self) -> Option<Self::Item> {
        match self.inner.next() {
            Some(sample) => Some(sample),
            None => {
                self.ended.store(true, Ordering::Release);
                None
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl<S> rodio::Source for EndNotifySource<S>
where
    S: rodio::Source<Item = i16>,
{
    fn current_frame_len(&self) -> Option<usize> {
        self.inner.current_frame_len()
    }

    fn channels(&self) -> u16 {
        self.inner.channels()
    }

    fn sample_rate(&self) -> u32 {
        self.inner.sample_rate()
    }

    fn total_duration(&self) -> Option<Duration> {
        self.inner.total_duration()
    }
}

fn open_output_stream(
    device_id: Option<&str>,
) -> Result<(rodio::OutputStream, rodio::OutputStreamHandle), String> {
    use rodio::cpal::traits::HostTrait;
    use rodio::{DeviceTrait, OutputStream};

    match device_id {
        None | Some("") | Some("default") => {
            OutputStream::try_default().map_err(|e| format!("no audio output device: {e}"))
        }
        Some(id) => {
            let index = id
                .strip_prefix("device:")
                .and_then(|s| s.parse::<usize>().ok())
                .ok_or_else(|| format!("invalid output device id '{id}'"))?;
            let host = rodio::cpal::default_host();
            let device = host
                .output_devices()
                .map_err(|e| format!("cannot list output devices: {e}"))?
                .nth(index)
                .ok_or_else(|| format!("output device '{id}' not found"))?;
            let name = device.name().unwrap_or_else(|_| id.to_string());
            OutputStream::try_from_device(&device)
                .map_err(|e| format!("cannot open output device '{name}': {e}"))
        }
    }
}

fn spawn_worker(shared: Arc<Shared>, last_error: Arc<Mutex<Option<String>>>) -> Sender<Cmd> {
    let (tx, rx) = channel();
    let spawned = std::thread::Builder::new()
        .name("peerbeat-audio".into())
        .spawn({
            let shared = shared.clone();
            let last_error = last_error.clone();
            move || {
                let result = catch_unwind(AssertUnwindSafe(|| {
                    run_loop(rx, shared.clone(), last_error.clone());
                }));
                if let Err(payload) = result {
                    let detail = panic_detail(payload);
                    let msg = format!("audio worker crashed: {detail}");
                    eprintln!("peerbeat: {msg}");
                    shared.playing.store(false, Ordering::Relaxed);
                    set_last_error(&last_error, Some(msg));
                }
            }
        });
    if let Err(e) = spawned {
        // Don't panic across the FFI boundary. `rx` was dropped with the
        // closure, so `tx.send()` will return Err and the engine surfaces
        // `last_error` instead of crashing the app.
        let msg = format!("cannot spawn audio thread: {e}");
        eprintln!("peerbeat: {msg}");
        set_last_error(&last_error, Some(msg));
    }
    tx
}

fn run_loop(rx: Receiver<Cmd>, shared: Arc<Shared>, last_error: Arc<Mutex<Option<String>>>) {
    use rodio::{Sink, Source};

    // `_stream` must stay alive for audio to play.
    let (mut _stream, mut handle) = match open_output_stream(None) {
        Ok(s) => s,
        Err(e) => {
            let msg = e;
            eprintln!("peerbeat: {msg}");
            set_last_error(&last_error, Some(msg.clone()));
            while let Ok(cmd) = rx.recv() {
                if let Cmd::Load(_, reply) = cmd {
                    let _ = reply.send(Err(msg.clone()));
                }
            }
            return;
        }
    };
    let mut sink = match Sink::try_new(&handle) {
        Ok(s) => s,
        Err(e) => {
            let msg = format!("cannot create audio sink: {e}");
            eprintln!("peerbeat: {msg}");
            set_last_error(&last_error, Some(msg.clone()));
            while let Ok(cmd) = rx.recv() {
                if let Cmd::Load(_, reply) = cmd {
                    let _ = reply.send(Err(msg.clone()));
                }
            }
            return;
        }
    };
    let mut volume = 1.0f32;
    let mut speed = 1.0f32;
    let eq = EqHandle::new();
    let widen = StereoWidenHandle::new();
    // Live, lock-free speed read by the time-stretch stage inside each sink's
    // source (no `sink.set_speed`, which would pitch-shift).
    let speed_handle = SpeedHandle::new();
    // Output-time anchor for the position calc: content_ms = base +
    // (sink.get_pos() - speed_anchor) * speed. Reset to ZERO on every fresh sink
    // (get_pos restarts at 0), and advanced on each speed change.
    let mut speed_anchor = Duration::ZERO;
    let mut current_path: Option<String> = None;
    let mut base_position_ms = 0u64;
    // Fractional-millisecond carry so repeated speed changes don't truncate-drift.
    let mut frac_ms = 0f64;
    let mut force_position_ms: Option<u64> = None;
    let mut current_duration = Duration::ZERO;
    // Crossfade state (inert while `crossfade_secs == 0`, i.e. the default):
    // `fade_in` ramps the incoming sink up; `fading_out` holds outgoing sinks
    // ramping down until they finish.
    let mut crossfade_secs = 0.0f32;
    let mut fade_in: Option<std::time::Instant> = None;
    let mut fading_out: Vec<(Sink, std::time::Instant)> = Vec::new();

    loop {
        match rx.recv_timeout(Duration::from_millis(150)) {
            Ok(Cmd::Load(path, reply)) => {
                let result: Result<(), String> = (|| {
                    shared.ended.store(false, Ordering::Release);
                    let source = with_dsp(
                        open_source(&path)?,
                        eq.clone(),
                        widen.clone(),
                        speed_handle.clone(),
                        shared.ended.clone(),
                    );
                    let dur = source.total_duration().unwrap_or(Duration::ZERO);
                    // A fresh sink avoids rodio 0.19 getting stuck after clear().
                    let s = Sink::try_new(&handle)
                        .map_err(|e| format!("cannot create audio sink: {e}"))?;
                    // Crossfade: if enabled and a track is currently audible, let the
                    // old sink fade out under the new one (which fades in). Otherwise
                    // swap sinks at full volume (the default, unchanged behaviour).
                    if crossfade_secs > 0.0 && !sink.is_paused() && !sink.empty() {
                        let now = std::time::Instant::now();
                        let old = std::mem::replace(&mut sink, s);
                        fading_out.push((old, now));
                        sink.set_volume(0.0);
                        fade_in = Some(now);
                    } else {
                        sink = s;
                        sink.set_volume(volume);
                        fade_in = None;
                    }
                    current_path = Some(path.clone());
                    current_duration = dur;
                    base_position_ms = 0;
                    frac_ms = 0.0;
                    speed_anchor = Duration::ZERO; // fresh sink: get_pos() restarts at 0
                    force_position_ms = None; // drop any pending seek from a prior track
                    engage_speed(&sink, speed, &speed_handle);
                    sink.append(source);
                    sink.play();
                    shared
                        .duration_ms
                        .store(dur.as_millis() as u64, Ordering::Relaxed);
                    shared.position_ms.store(0, Ordering::Relaxed);
                    shared.playing.store(true, Ordering::Relaxed);
                    Ok(())
                })();
                match &result {
                    Ok(()) => set_last_error(&last_error, None),
                    Err(e) => {
                        eprintln!("peerbeat: {e}");
                        shared.duration_ms.store(0, Ordering::Relaxed);
                        shared.position_ms.store(0, Ordering::Relaxed);
                        shared.playing.store(false, Ordering::Relaxed);
                        set_last_error(&last_error, Some(e.clone()));
                    }
                }
                let _ = reply.send(result);
            }
            Ok(Cmd::Pause) => {
                sink.pause();
                fading_out.clear(); // don't keep a crossfade tail audible while paused
            }
            Ok(Cmd::Resume) => sink.play(),
            Ok(Cmd::Stop) => {
                if let Ok(s) = Sink::try_new(&handle) {
                    sink = s;
                    sink.set_volume(volume);
                }
                speed_anchor = Duration::ZERO;
                fade_in = None;
                fading_out.clear();
                current_path = None;
                current_duration = Duration::ZERO;
                base_position_ms = 0;
                frac_ms = 0.0;
                force_position_ms = None;
                shared.ended.store(false, Ordering::Release);
                shared.duration_ms.store(0, Ordering::Relaxed);
                shared.position_ms.store(0, Ordering::Relaxed);
                shared.playing.store(false, Ordering::Relaxed);
            }
            Ok(Cmd::Seek(ms, reply)) => {
                let result: Result<(), String> = (|| {
                    let path = current_path
                        .as_deref()
                        .ok_or_else(|| "no track loaded".to_string())?;
                    let requested = Duration::from_millis(ms);
                    let target = clamp_seek_position(
                        requested,
                        (current_duration != Duration::ZERO).then_some(current_duration),
                    );
                    let visible = if current_duration == Duration::ZERO {
                        requested
                    } else {
                        requested.min(current_duration)
                    };
                    let visible_ms = visible.as_millis() as u64;
                    let target_ms = target.as_millis() as u64;
                    let was_playing = !sink.is_paused() && !sink.empty();
                    shared.ended.store(false, Ordering::Release);
                    let source = open_seeked_source(
                        path,
                        target,
                        eq.clone(),
                        widen.clone(),
                        speed_handle.clone(),
                        shared.ended.clone(),
                    )?;
                    let s = Sink::try_new(&handle)
                        .map_err(|e| format!("cannot create audio sink: {e}"))?;
                    sink = s;
                    sink.set_volume(volume);
                    speed_anchor = Duration::ZERO;
                    engage_speed(&sink, speed, &speed_handle);
                    fade_in = None;
                    fading_out.clear();
                    sink.append(source);
                    if was_playing {
                        sink.play();
                    } else {
                        sink.pause();
                    }
                    base_position_ms = target_ms;
                    frac_ms = 0.0;
                    shared.position_ms.store(visible_ms, Ordering::Relaxed);
                    force_position_ms = Some(visible_ms);
                    set_last_error(&last_error, None);
                    Ok(())
                })();
                if let Err(e) = &result {
                    set_last_error(&last_error, Some(e.clone()));
                }
                let _ = reply.send(result);
            }
            Ok(Cmd::Volume(v)) => {
                volume = v;
                sink.set_volume(v);
            }
            Ok(Cmd::Speed(s)) => {
                // Rebase the position accumulator with the OLD speed so the
                // scrubber stays continuous across the change, then engage the new
                // speed in the time-stretch stage (no pitch-shifting sink.set_speed).
                let out = sink.get_pos();
                let since = out.saturating_sub(speed_anchor);
                let advance = since.as_secs_f64() * speed as f64 * 1000.0 + frac_ms;
                let whole = advance.floor();
                base_position_ms += whole as u64;
                frac_ms = advance - whole;
                speed_anchor = out;
                speed = s;
                engage_speed(&sink, s, &speed_handle);
            }
            Ok(Cmd::Eq(gains, preamp_db)) => {
                eq.set(gains, preamp_db);
            }
            Ok(Cmd::Device(device_id, reply)) => {
                let result: Result<(), String> = (|| {
                    let was_playing = !sink.is_paused() && !sink.empty();
                    let resume_ms = shared.position_ms.load(Ordering::Relaxed);
                    let (new_stream, new_handle) = open_output_stream(device_id.as_deref())?;
                    let s = Sink::try_new(&new_handle)
                        .map_err(|e| format!("cannot create audio sink: {e}"))?;
                    _stream = new_stream;
                    handle = new_handle;
                    sink = s;
                    sink.set_volume(volume);
                    speed_anchor = Duration::ZERO;
                    engage_speed(&sink, speed, &speed_handle);
                    // Outgoing crossfade sinks belong to the old stream — drop them.
                    fade_in = None;
                    fading_out.clear();
                    if let Some(path) = current_path.as_deref() {
                        let target = clamp_seek_position(
                            Duration::from_millis(resume_ms),
                            (current_duration != Duration::ZERO).then_some(current_duration),
                        );
                        shared.ended.store(false, Ordering::Release);
                        let source = open_seeked_source(
                            path,
                            target,
                            eq.clone(),
                            widen.clone(),
                            speed_handle.clone(),
                            shared.ended.clone(),
                        )?;
                        sink.append(source);
                        base_position_ms = target.as_millis() as u64;
                        frac_ms = 0.0;
                        force_position_ms = Some(base_position_ms);
                        if was_playing {
                            sink.play();
                        } else {
                            sink.pause();
                        }
                    }
                    set_last_error(&last_error, None);
                    Ok(())
                })();
                if let Err(e) = &result {
                    set_last_error(&last_error, Some(e.clone()));
                }
                let _ = reply.send(result);
            }
            Ok(Cmd::StereoWidth(width)) => {
                widen.set(width);
            }
            Ok(Cmd::Crossfade(secs)) => {
                crossfade_secs = secs;
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
        // Advance any active crossfade. No-op while disabled (the default).
        if crossfade_secs > 0.0 {
            let now = std::time::Instant::now();
            if let Some(start) = fade_in {
                let frac =
                    (now.duration_since(start).as_secs_f32() / crossfade_secs).clamp(0.0, 1.0);
                if frac >= 1.0 {
                    fade_in = None;
                    sink.set_volume(volume);
                } else {
                    sink.set_volume(volume * frac);
                }
            }
            let had_tail = !fading_out.is_empty();
            fading_out.retain_mut(|(s, start)| {
                let frac =
                    (now.duration_since(*start).as_secs_f32() / crossfade_secs).clamp(0.0, 1.0);
                if frac >= 1.0 {
                    false // drop → the Sink stops
                } else {
                    s.set_volume(volume * (1.0 - frac));
                    true
                }
            });
            // The outgoing track flips the shared `ended` flag as its tail
            // finishes; that belongs to the old track, so clear it while a
            // crossfade is live (and on the tick it completes). The incoming
            // track sets it again when it genuinely ends, long after the fade.
            if fade_in.is_some() || !fading_out.is_empty() || had_tail {
                shared.ended.store(false, Ordering::Release);
            }
        }
        let ended = shared.ended.load(Ordering::Acquire);
        let pos_ms = if ended && current_duration != Duration::ZERO {
            current_duration.as_millis() as u64
        } else {
            force_position_ms.take().unwrap_or_else(|| {
                // The time-stretch stage consumes `speed` source-seconds of content
                // per output (wall-clock) second, so content advances at
                // (wall-time since the last anchor) × speed. base_position_ms holds
                // the content position banked at that anchor (track start, seek, or
                // the last speed change); no-op scaling at 1.0×.
                let since = sink.get_pos().saturating_sub(speed_anchor);
                let content_ms = since.as_secs_f64() * speed as f64 * 1000.0;
                base_position_ms + content_ms as u64
            })
        };
        shared.position_ms.store(pos_ms, Ordering::Relaxed);
        shared.playing.store(
            !ended && !sink.is_paused() && !sink.empty(),
            Ordering::Relaxed,
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rodio::buffer::SamplesBuffer;

    #[test]
    fn end_notify_source_sets_flag_at_eof() {
        let ended = Arc::new(AtomicBool::new(false));
        let src = SamplesBuffer::new(1, 44_100, vec![1i16, 2i16]);
        let mut wrapped = EndNotifySource::new(src, ended.clone());

        assert_eq!(wrapped.next(), Some(1));
        assert_eq!(wrapped.next(), Some(2));
        assert!(!ended.load(Ordering::Acquire));
        assert_eq!(wrapped.next(), None);
        assert!(ended.load(Ordering::Acquire));
    }

    fn write_min_wav(path: &std::path::Path) {
        use std::io::Write;
        let sample_rate: u32 = 8000;
        let data_len: u32 = sample_rate * 2; // ~1s, mono 16-bit
        let mut f = std::fs::File::create(path).unwrap();
        f.write_all(b"RIFF").unwrap();
        f.write_all(&(36 + data_len).to_le_bytes()).unwrap();
        f.write_all(b"WAVE").unwrap();
        f.write_all(b"fmt ").unwrap();
        f.write_all(&16u32.to_le_bytes()).unwrap();
        f.write_all(&1u16.to_le_bytes()).unwrap(); // PCM
        f.write_all(&1u16.to_le_bytes()).unwrap(); // mono
        f.write_all(&sample_rate.to_le_bytes()).unwrap();
        f.write_all(&(sample_rate * 2).to_le_bytes()).unwrap();
        f.write_all(&2u16.to_le_bytes()).unwrap();
        f.write_all(&16u16.to_le_bytes()).unwrap();
        f.write_all(b"data").unwrap();
        f.write_all(&data_len.to_le_bytes()).unwrap();
        f.write_all(&vec![0u8; data_len as usize]).unwrap();
    }

    #[test]
    fn open_source_decodes_unknown_extension_via_symphonia() {
        // A LAN stream cached without a codec extension (".audio") must still
        // decode by content-probing with symphonia — not fall into rodio's
        // generic decoder, which panics on some streamed inputs.
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("peerbeat_eng_{nanos}.audio"));
        write_min_wav(&path);
        let src = open_source(path.to_str().unwrap());
        assert!(
            src.is_ok(),
            "unknown-ext source should open: {:?}",
            src.err()
        );
        std::fs::remove_file(&path).ok();
    }
}
