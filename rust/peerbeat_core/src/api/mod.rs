//! The flutter_rust_bridge API boundary.
//!
//! Functions and types exposed here (and only here) are what the Dart side can
//! call. Each submodule wraps an internal subsystem with FRB-friendly,
//! serialisable signatures. Keep this layer thin: validation + translation, no
//! business logic.

pub mod system;

// Added per milestone as subsystems land:
// pub mod library;   // M1 — scan/browse/search/tags
// pub mod audio;     // M1 — desktop transport + DSP control
// pub mod network;   // M2 — host/peer, sharing, party mode
