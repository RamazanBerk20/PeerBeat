//! FRB LAN API: host (advertise + serve over TLS) and discover peers.

use crate::net::discovery::{self, HostInfo};
use crate::net::server::{self, ServerConfig};
use crate::net::tls;
use axum_server::tls_rustls::RustlsConfig;
use axum_server::Handle;
use mdns_sd::ServiceDaemon;
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
    });
    Ok(port)
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
