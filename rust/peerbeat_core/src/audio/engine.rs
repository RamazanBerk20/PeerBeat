//! Desktop audio engine (interim) built on `rodio`.
//!
//! rodio's stream/sink are `!Send`, so the engine owns them on a dedicated
//! thread and is driven by a command channel; playback state is published via
//! shared atomics the FRB layer reads. This delivers M1 transport
//! (load/play/pause/seek/volume + position). The DSP graph (10-band EQ,
//! crossfade, ReplayGain, pitch-preserving speed) is the M2 custom
//! symphonia→cpal path that replaces rodio here.

use std::io::BufReader;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::sync::Arc;
use std::time::Duration;

enum Cmd {
    Load(String),
    Resume,
    Pause,
    Stop,
    Seek(u64),
    Volume(f32),
}

#[derive(Default)]
struct Shared {
    position_ms: AtomicU64,
    duration_ms: AtomicU64,
    playing: AtomicBool,
}

/// Handle to the audio thread. `Send + Sync` (only a channel sender + atomics),
/// so it lives in a process-wide `OnceLock`.
pub struct AudioEngine {
    tx: Sender<Cmd>,
    shared: Arc<Shared>,
}

impl AudioEngine {
    pub fn new() -> Self {
        let (tx, rx) = channel();
        let shared = Arc::new(Shared::default());
        let shared_thread = shared.clone();
        std::thread::Builder::new()
            .name("peerbeat-audio".into())
            .spawn(move || run(rx, shared_thread))
            .expect("spawn audio thread");
        Self { tx, shared }
    }

    pub fn load(&self, path: String) {
        let _ = self.tx.send(Cmd::Load(path));
    }
    pub fn pause(&self) {
        let _ = self.tx.send(Cmd::Pause);
    }
    pub fn resume(&self) {
        let _ = self.tx.send(Cmd::Resume);
    }
    pub fn stop(&self) {
        let _ = self.tx.send(Cmd::Stop);
    }
    pub fn seek(&self, ms: u64) {
        let _ = self.tx.send(Cmd::Seek(ms));
    }
    pub fn set_volume(&self, v: f32) {
        let _ = self.tx.send(Cmd::Volume(v.clamp(0.0, 2.0)));
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
}

impl Default for AudioEngine {
    fn default() -> Self {
        Self::new()
    }
}

fn run(rx: Receiver<Cmd>, shared: Arc<Shared>) {
    use rodio::{Decoder, OutputStream, Sink, Source};

    // `_stream` must stay alive for audio to play.
    let (_stream, handle) = match OutputStream::try_default() {
        Ok(s) => s,
        Err(_) => return, // no audio device; engine is inert
    };
    let sink = match Sink::try_new(&handle) {
        Ok(s) => s,
        Err(_) => return,
    };

    loop {
        match rx.recv_timeout(Duration::from_millis(150)) {
            Ok(Cmd::Load(path)) => match std::fs::File::open(&path)
                .ok()
                .and_then(|f| Decoder::new(BufReader::new(f)).ok())
            {
                Some(dec) => {
                    let dur = dec.total_duration().unwrap_or(Duration::ZERO);
                    sink.clear();
                    sink.append(dec);
                    sink.play();
                    shared
                        .duration_ms
                        .store(dur.as_millis() as u64, Ordering::Relaxed);
                }
                None => shared.duration_ms.store(0, Ordering::Relaxed),
            },
            Ok(Cmd::Pause) => sink.pause(),
            Ok(Cmd::Resume) => sink.play(),
            Ok(Cmd::Stop) => {
                sink.clear();
                shared.duration_ms.store(0, Ordering::Relaxed);
            }
            Ok(Cmd::Seek(ms)) => {
                let _ = sink.try_seek(Duration::from_millis(ms));
            }
            Ok(Cmd::Volume(v)) => sink.set_volume(v),
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
        shared
            .position_ms
            .store(sink.get_pos().as_millis() as u64, Ordering::Relaxed);
        shared
            .playing
            .store(!sink.is_paused() && !sink.empty(), Ordering::Relaxed);
    }
}
