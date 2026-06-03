//! LAN host HTTP server (axum). Serves library metadata + audio bytes to peers.
//!
//! Endpoints today: `/v1/info`, `/v1/tracks`, and `/v1/stream/{id}` (the stream
//! route honors HTTP Range via `ServeFile`, so peers can seek). The listener is
//! wrapped in TLS with a per-host self-signed cert in [`crate::api::network`];
//! peers pin that cert via TOFU.
//!
//! Not yet built (roadmap, see `docs/STATUS.md`): the access modes (Open / PIN /
//! Approved), per-playlist share scoping + permissions, download endpoints, and the
//! WebSocket control / party channel. Until then every endpoint is unauthenticated —
//! any LAN peer can list and stream the whole library — so hosting is opt-in and off
//! by default.

use crate::db::tracks;
use axum::{
    extract::{Path, Request, State},
    http::StatusCode,
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use rusqlite::Connection;
use serde::Serialize;
use std::path::PathBuf;
use tower::ServiceExt;
use tower_http::services::ServeFile;

#[derive(Clone)]
pub struct ServerConfig {
    pub db_path: PathBuf,
    pub name: String,
    pub host_id: String,
    pub fingerprint: String,
}

#[derive(Serialize)]
struct InfoResp {
    name: String,
    host_id: String,
    fingerprint: String,
    track_count: i64,
    proto: u32,
}

#[derive(Serialize)]
struct TrackDto {
    id: i64,
    title: String,
    artist: String,
    album: String,
    duration_ms: i64,
}

pub fn router(cfg: ServerConfig) -> Router {
    Router::new()
        .route("/v1/info", get(info))
        .route("/v1/tracks", get(list_tracks))
        .route("/v1/stream/{id}", get(stream))
        .with_state(cfg)
}

async fn blocking_db<T, F>(db_path: PathBuf, f: F) -> Option<T>
where
    F: FnOnce(&Connection) -> rusqlite::Result<T> + Send + 'static,
    T: Send + 'static,
{
    tokio::task::spawn_blocking(move || {
        let conn = Connection::open(&db_path).ok()?;
        f(&conn).ok()
    })
    .await
    .ok()
    .flatten()
}

async fn info(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    let count = blocking_db(cfg.db_path.clone(), |c| {
        c.query_row("SELECT count(*) FROM tracks", [], |r| r.get::<_, i64>(0))
    })
    .await
    .unwrap_or(0);
    Json(InfoResp {
        name: cfg.name.clone(),
        host_id: cfg.host_id.clone(),
        fingerprint: cfg.fingerprint.clone(),
        track_count: count,
        proto: 1,
    })
}

async fn list_tracks(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    let rows = blocking_db(cfg.db_path.clone(), |c| {
        let songs = tracks::browse_songs(c, 100_000, 0)?;
        Ok(songs
            .into_iter()
            .map(|t| TrackDto {
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
                duration_ms: t.duration_ms,
            })
            .collect::<Vec<_>>())
    })
    .await
    .unwrap_or_default();
    Json(rows)
}

/// Stream a track's original bytes. Delegates to `ServeFile`, which honors HTTP
/// Range (206 Partial Content for seeking), streams the body in chunks (no
/// whole-file buffering), and sets Content-Type/Length/Accept-Ranges. The path
/// is resolved from the scanned library by id (never from the request), so
/// there is no path traversal.
async fn stream(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    request: Request,
) -> impl IntoResponse {
    let file_path = blocking_db(cfg.db_path.clone(), move |c| {
        c.query_row("SELECT path FROM tracks WHERE id = ?1", [id], |r| {
            r.get::<_, String>(0)
        })
    })
    .await;
    let Some(file_path) = file_path else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    match ServeFile::new(&file_path).oneshot(request).await {
        Ok(resp) => resp.into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "file missing").into_response(),
    }
}

/// Bind `0.0.0.0:0` and return a non-blocking std listener (for `axum_server`)
/// + the chosen port.
pub fn bind_std() -> std::io::Result<(std::net::TcpListener, u16)> {
    let listener = std::net::TcpListener::bind(("0.0.0.0", 0))?;
    let port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;
    Ok((listener, port))
}
