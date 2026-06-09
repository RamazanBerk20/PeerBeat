//! LAN protocol — the PeerBeat differentiator.
//!
//! - **Discovery**: `mdns-sd` advertises/browses `_peerbeat._tcp` (no Avahi
//!   daemon dependency); manual IP (with IPv6 fallback) as a backup.
//! - **Transport**: a single TLS port (rustls + a per-host self-signed `rcgen`
//!   cert) serving a versioned REST API (axum/hyper, HTTP Range for audio) plus
//!   a WebSocket control channel for party mode.
//! - **Security**: TOFU pinning of the peer's certificate SHA-256 — the core
//!   controls both ends, so a pinned host is trusted without a CA. (The desktop
//!   client caches a pinned stream to a size-capped temp file before playback.)
//! - **Auth**: Open / PIN (Argon2id) / Approved-peers → a scoped session bearer
//!   token with a 12 h TTL (stored hashed), rate-limited, one-tap revocable.
//! - **Party mode**: a Cristian clock-sync handshake keeps peers within ~100 ms,
//!   clearly separate from independent pull-streaming.
//!
//! See `docs/protocol.md`, `docs/security.md`, and `docs/STATUS.md`.

pub mod discovery;
pub mod party;
pub mod server;
pub mod tls;

// Further slices:
// mod control;      // websocket control channel
// mod party;        // clock-sync + synchronized playback
