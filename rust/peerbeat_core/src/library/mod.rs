//! Local library: scanning, metadata, and (later) watch-folders.
//!
//! - Tag read/properties via `lofty` (MP3/FLAC/WAV/AAC/OGG/M4A).
//! - Incremental scan: a `(size, mtime)` fingerprint gates an `xxh3` content
//!   hash of `[head + tail + size]`, so rescans only re-parse changed files.
//!
//! Implemented in **M1** (scan + tag read) and extended in **M2** (tag
//! write-back, watch-folders via `notify`, M3U/PLS import-export).

pub mod metadata;
pub mod scan;

pub use metadata::{is_audio, read_tags, AUDIO_EXTS};
pub use scan::{scan_folder, ScanStats};
