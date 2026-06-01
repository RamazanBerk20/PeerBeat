//! LAN protocol — the PeerBeat differentiator.
//!
//! - **Discovery**: `mdns-sd` advertises/browses `_peerbeat._tcp` (no Avahi
//!   daemon dependency); manual IP + QR pairing as fallbacks.
//! - **Transport**: a single TLS port (rustls + a per-host self-signed `rcgen`
//!   cert) serving a versioned REST API (axum/hyper, HTTP Range for audio) and a
//!   WebSocket control channel (tokio-tungstenite).
//! - **Security**: TOFU pinning of the peer's SPKI SHA-256 — the core controls
//!   both the server and the streaming client, so a pinned stream is fed
//!   straight to the decoder with no localhost-proxy workaround.
//! - **Auth**: Open / PIN / Approved-peers → a session bearer token bound to the
//!   pinned fingerprint and scoped to the granted shares; one-tap revoke.
//! - **Party mode**: a Cristian/NTP clock-sync handshake keeping peers within
//!   ~100 ms; clearly separate from independent pull-streaming.
//!
//! See `docs/protocol.md` and `docs/security.md`.
//!
//! Implemented in **M2** (discovery, host server, streaming, sharing, auth) and
//! **M3** (party mode).

pub mod discovery;
pub mod server;
pub mod tls;

// Further slices:
// mod control;      // websocket control channel
// mod party;        // clock-sync + synchronized playback
