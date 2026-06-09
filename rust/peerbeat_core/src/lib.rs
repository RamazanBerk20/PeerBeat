//! # peerbeat_core
//!
//! The shared native core for **PeerBeat**, compiled to a `cdylib` and loaded by
//! the Flutter UI on Windows, Linux, and Android via `flutter_rust_bridge`.
//!
//! Module map:
//! - [`api`]     — the flutter_rust_bridge boundary (the only public surface the
//!                 Dart side calls). Everything else is implementation detail.
//! - [`db`]      — SQLite (rusqlite) store: schema, migrations, FTS5 search.
//! - [`library`] — filesystem scanning, tag read/write (lofty), watch-folders.
//! - [`audio`]   — the desktop audio engine (symphonia → DSP → cpal).
//! - [`net`]     — LAN protocol: discovery, TLS host server, streaming, party sync.
//!
//! Platform note: on Android, playback is handled by ExoPlayer on the Dart side;
//! [`audio`] is therefore a desktop-only engine, while [`db`], [`library`], and
//! [`net`] are used on every platform.

// Our module docs use lists whose continuation lines are aligned with the item
// text for readability; that trips this style-only lint.
#![allow(clippy::doc_overindented_list_items)]
// The flutter_rust_bridge attribute macro emits its own `frb_` cfgs.
#![allow(unexpected_cfgs)]

pub mod api;
pub mod audio;
pub mod db;
pub mod i18n;
pub mod library;
pub mod net;

// flutter_rust_bridge generated glue (regenerate via `melos run frb-gen`).
mod frb_generated;
