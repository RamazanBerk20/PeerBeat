//! LAN protocol — the PeerBeat differentiator.
//!
//! - **Discovery**: `mdns-sd` advertises/browses `_peerbeat._tcp` (no Avahi
//!   daemon dependency); manual IP as a fallback (QR pairing planned).
//! - **Transport**: a single TLS port (rustls + a per-host self-signed `rcgen`
//!   cert) serving a versioned REST API (axum/hyper, HTTP Range for audio). A
//!   WebSocket control channel (tokio-tungstenite) is planned for party mode.
//! - **Security**: TOFU pinning of the peer's certificate SHA-256 — the core
//!   controls both ends, so a pinned host can be trusted without a CA. (The
//!   desktop client currently caches a pinned stream to a temp file before
//!   playback; feeding bytes straight to the decoder is a roadmap item.)
//! - **Auth** *(planned)*: Open / PIN / Approved-peers → a session bearer token
//!   bound to the pinned fingerprint and scoped to the granted shares; one-tap revoke.
//! - **Party mode** *(planned)*: a Cristian/NTP clock-sync handshake keeping peers
//!   within ~100 ms; clearly separate from independent pull-streaming.
//!
//! See `docs/protocol.md`, `docs/security.md`, and current status in `docs/STATUS.md`.
//!
//! **Built today:** discovery, the TLS host server, and Range streaming with TOFU
//! pinning. **Planned:** marking playlists shareable, the access modes/auth above,
//! per-playlist permissions, downloads, the WebSocket control channel, and party mode.

pub mod discovery;
pub mod party;
pub mod server;
pub mod tls;

// Further slices:
// mod control;      // websocket control channel
// mod party;        // clock-sync + synchronized playback
