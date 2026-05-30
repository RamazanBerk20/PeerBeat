//! Local library: scanning, metadata, and watch-folders.
//!
//! - Decode-probe + tag read/write via `lofty` and `symphonia` (MP3/FLAC/WAV/
//!   AAC/OGG/M4A; OGG/Opus tag-write included).
//! - Embedded album-art extraction to a content-hash-keyed on-disk cache.
//! - Incremental change detection: a cheap `(size, mtime)` fingerprint gates an
//!   `xxh3` content hash of `[first 64 KiB + last 64 KiB + size]`, so rescans
//!   only re-parse changed files.
//! - Watch-folders via `notify`, debounced and coalesced into batch transactions.
//!
//! Implemented in **M1** (scan + tag read + art cache) and extended in **M2**
//! (tag write-back, watch-folders, M3U/PLS import-export).

// Submodules land in M1:
// mod scan;         // walkdir + incremental change detection
// mod metadata;     // lofty/symphonia read + write
// mod art;          // embedded art extraction + cache
// mod watch;        // notify-based folder watching
// mod playlist_io;  // M3U / PLS import-export
