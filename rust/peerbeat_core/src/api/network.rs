//! FRB LAN API: host (advertise + serve over TLS) and discover peers.

use crate::db::remembered_peers;
use crate::net::discovery::{self, HostInfo};
use crate::net::party::PartyState;
use crate::net::server::{self, ServerConfig};
use crate::net::tls;
use axum_server::tls_rustls::RustlsConfig;
use axum_server::Handle;
use mdns_sd::ServiceDaemon;
use rusqlite::Connection;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::thread::JoinHandle;
use std::time::Duration;

struct Host {
    daemon: ServiceDaemon,
    handle: Handle<std::net::SocketAddr>,
    thread: Option<JoinHandle<()>>,
    port: u16,
    sessions: server::Sessions,
    party: server::PartyHub,
    approvals: server::Approvals,
    db_path: PathBuf,
    host_id: String,
}

static HOST: Mutex<Option<Host>> = Mutex::new(None);

/// Start sharing the library over the LAN: bind the **HTTPS** server (per-host
/// self-signed cert) and advertise it (name + stable id + fingerprint) via
/// mDNS. Returns the port. Idempotent (returns the existing port).
pub fn net_start_host(db_path: String, display_name: String) -> Result<u16, String> {
    let mut guard = HOST.lock().map_err(|_| "host lock poisoned".to_string())?;
    if let Some(h) = guard.as_ref() {
        return Ok(h.port);
    }

    tls::ensure_provider();
    // Certs live next to the database file.
    let dir = Path::new(&db_path)
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));
    let identity = tls::load_or_create(&dir).map_err(|e| e.to_string())?;

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(|e| e.to_string())?;
    let tls_config = rt
        .block_on(RustlsConfig::from_pem(
            identity.cert_pem.clone().into_bytes(),
            identity.key_pem.clone().into_bytes(),
        ))
        .map_err(|e| format!("tls config: {e}"))?;
    let (listener, port) = server::bind_std().map_err(|e| e.to_string())?;

    let daemon = ServiceDaemon::new().map_err(|e| e.to_string())?;
    discovery::register(
        &daemon,
        &display_name,
        port,
        &identity.host_id,
        &identity.fingerprint,
    )
    .map_err(|e| e.to_string())?;

    let cfg = ServerConfig::new(
        PathBuf::from(&db_path),
        display_name,
        identity.host_id,
        identity.fingerprint,
    );
    let sessions = cfg.sessions.clone();
    let party = cfg.party.clone();
    let approvals = cfg.approvals.clone();
    let host_id = cfg.host_id.clone();
    let handle: Handle<std::net::SocketAddr> = Handle::new();
    let handle_thread = handle.clone();
    let thread = std::thread::Builder::new()
        .name("peerbeat-host".into())
        .spawn(move || {
            rt.block_on(async move {
                let app = server::router(cfg);
                match axum_server::from_tcp_rustls(listener, tls_config) {
                    Ok(server) => {
                        let _ = server
                            .handle(handle_thread)
                            .serve(
                                app.into_make_service_with_connect_info::<std::net::SocketAddr>(),
                            )
                            .await;
                    }
                    Err(e) => eprintln!("peerbeat: tls server failed: {e}"),
                }
            });
        })
        .map_err(|e| e.to_string())?;

    *guard = Some(Host {
        daemon,
        handle,
        thread: Some(thread),
        port,
        sessions,
        party,
        approvals,
        db_path: PathBuf::from(&db_path),
        host_id,
    });
    Ok(port)
}

/// A peer waiting for the host to allow/deny it (approved-peers share mode),
/// surfaced to the host UI.
pub struct PendingApprovalDto {
    pub challenge: String,
    pub peer: String,
    pub label: String,
    pub requested_at_ms: i64,
}

/// Peers currently awaiting an allow/deny decision from the host.
pub fn net_pending_approvals() -> Vec<PendingApprovalDto> {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            if let Ok(a) = h.approvals.lock() {
                return a
                    .iter()
                    .filter(|p| p.decision.is_none())
                    .map(|p| PendingApprovalDto {
                        challenge: p.challenge.clone(),
                        peer: p.peer.clone(),
                        label: p.label.clone(),
                        requested_at_ms: p.requested_at_ms,
                    })
                    .collect();
            }
        }
    }
    Vec::new()
}

/// Allow or deny a pending peer by its `challenge`. With `remember`, the decision
/// is persisted (so the peer is auto-handled next time). False if not hosting or
/// the challenge is unknown.
pub fn net_decide_peer(challenge: String, allow: bool, remember: bool) -> bool {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            let peer = {
                let Ok(mut a) = h.approvals.lock() else {
                    return false;
                };
                let Some(p) = a.iter_mut().find(|p| p.challenge == challenge) else {
                    return false;
                };
                p.decision = Some(allow);
                p.peer.clone()
            };
            if remember {
                if let Ok(conn) = Connection::open(&h.db_path) {
                    let _ = remembered_peers::set(&conn, &h.host_id, &peer, allow, unix_ms());
                }
            }
            return true;
        }
    }
    false
}

/// Revoke every peer session token (they must re-authenticate). Used by the
/// host's "revoke all access" control. Returns false if not currently hosting.
pub fn net_revoke_all() -> bool {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            if let Ok(mut s) = h.sessions.lock() {
                s.clear();
            }
            return true;
        }
    }
    false
}

/// Revoke every session belonging to one peer IP. Returns false if not hosting.
pub fn net_revoke_peer(peer: String) -> bool {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            if let Ok(mut s) = h.sessions.lock() {
                s.retain(|_, sess| sess.peer != peer);
            }
            return true;
        }
    }
    false
}

/// The distinct peer IPs that currently hold a valid session token.
pub fn net_active_peers() -> Vec<String> {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            if let Ok(s) = h.sessions.lock() {
                let mut peers: Vec<String> = s.values().map(|x| x.peer.clone()).collect();
                peers.sort();
                peers.dedup();
                return peers;
            }
        }
    }
    Vec::new()
}

// ── Party mode (host side) ───────────────────────────────────────────────────

fn with_host(f: impl FnOnce(&Host)) -> bool {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            f(h);
            return true;
        }
    }
    false
}

fn unix_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// Begin a synchronized party session (requires hosting). Returns false if not hosting.
pub fn net_party_start() -> bool {
    with_host(|h| h.party.start())
}

/// Broadcast the host's current playback snapshot to all party peers. `track_key`
/// is the track's content hash so peers resolve it locally or stream it.
pub fn net_party_update(track_key: String, position_ms: i64, playing: bool) -> bool {
    with_host(|h| {
        h.party.broadcast_state(&PartyState {
            track_key,
            position_ms,
            playing,
            host_time_ms: unix_ms(),
        });
    })
}

/// End the party session (peers get an `ended` message).
pub fn net_party_stop() -> bool {
    with_host(|h| h.party.stop())
}

/// A peer's pending request to play a track during a party (host side).
pub struct PartyRequestDto {
    pub peer: String,
    pub track_id: i64,
    pub title: String,
    pub at_ms: i64,
}

/// Drain pending party track-requests, resolving each to a title from the host's
/// library. Drained entries are removed, so the UI should accumulate them.
pub fn net_party_requests() -> Vec<PartyRequestDto> {
    if let Ok(guard) = HOST.lock() {
        if let Some(h) = guard.as_ref() {
            let reqs = h.party.drain_requests();
            if reqs.is_empty() {
                return Vec::new();
            }
            let conn = Connection::open(&h.db_path).ok();
            return reqs
                .into_iter()
                .map(|r| {
                    let title = conn
                        .as_ref()
                        .and_then(|c| crate::db::tracks::track_by_id(c, r.track_id).ok().flatten())
                        .map(|t| t.title)
                        .unwrap_or_else(|| format!("Track {}", r.track_id));
                    PartyRequestDto {
                        peer: r.peer,
                        track_id: r.track_id,
                        title,
                        at_ms: r.at_ms,
                    }
                })
                .collect();
        }
    }
    Vec::new()
}

/// Whether a party session is currently active on this host.
pub fn net_party_active() -> bool {
    HOST.lock()
        .ok()
        .and_then(|g| g.as_ref().map(|h| h.party.is_active()))
        .unwrap_or(false)
}

/// Stop hosting (unadvertise + shut the server down).
pub fn net_stop_host() {
    if let Ok(mut guard) = HOST.lock() {
        if let Some(mut h) = guard.take() {
            h.handle.graceful_shutdown(Some(Duration::from_millis(500)));
            let _ = h.daemon.shutdown();
            if let Some(t) = h.thread.take() {
                let _ = t.join();
            }
        }
    }
}

pub fn net_is_hosting() -> bool {
    HOST.lock().map(|g| g.is_some()).unwrap_or(false)
}

pub fn net_host_port() -> Option<u16> {
    HOST.lock().ok().and_then(|g| g.as_ref().map(|h| h.port))
}

/// Browse the LAN for hosts for `timeout_ms`, returning the resolved peers.
pub fn net_discover(timeout_ms: i64) -> Vec<HostInfo> {
    discovery::browse(Duration::from_millis(timeout_ms.max(200) as u64))
}
