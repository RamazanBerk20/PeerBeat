//! FRB LAN API: host (advertise + serve) and discover peers.

use crate::net::discovery::{self, HostInfo};
use crate::net::server::{self, ServerConfig};
use mdns_sd::ServiceDaemon;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;
use std::time::Duration;
use tokio::sync::Notify;

struct Host {
    daemon: ServiceDaemon,
    shutdown: Arc<Notify>,
    thread: Option<JoinHandle<()>>,
    port: u16,
}

static HOST: Mutex<Option<Host>> = Mutex::new(None);

/// Start sharing the library over the LAN: bind the HTTP server and advertise
/// via mDNS. Returns the port. Idempotent (returns the existing port).
pub fn net_start_host(db_path: String, display_name: String) -> Result<u16, String> {
    let mut guard = HOST.lock().map_err(|_| "host lock poisoned".to_string())?;
    if let Some(h) = guard.as_ref() {
        return Ok(h.port);
    }

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(|e| e.to_string())?;
    let (listener, port) = rt.block_on(server::bind()).map_err(|e| e.to_string())?;

    let daemon = ServiceDaemon::new().map_err(|e| e.to_string())?;
    discovery::register(&daemon, &display_name, port).map_err(|e| e.to_string())?;

    let cfg = ServerConfig {
        db_path: PathBuf::from(&db_path),
        name: display_name,
    };
    let shutdown = Arc::new(Notify::new());
    let shutdown_thread = shutdown.clone();
    let thread = std::thread::Builder::new()
        .name("peerbeat-host".into())
        .spawn(move || {
            rt.block_on(async move {
                let app = server::router(cfg);
                let _ = axum::serve(listener, app)
                    .with_graceful_shutdown(async move { shutdown_thread.notified().await })
                    .await;
            });
        })
        .map_err(|e| e.to_string())?;

    *guard = Some(Host {
        daemon,
        shutdown,
        thread: Some(thread),
        port,
    });
    Ok(port)
}

/// Stop hosting (unadvertise + shut the server down).
pub fn net_stop_host() {
    if let Ok(mut guard) = HOST.lock() {
        if let Some(mut h) = guard.take() {
            h.shutdown.notify_one();
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
