//! LAN host HTTP server (axum). Serves library metadata + audio bytes to peers.
//!
//! Endpoints: public `/v1/info` and `/v1/shares` (so a peer can see what is
//! shareable and in which mode); `POST /v1/auth/session` issues a bearer token
//! for a chosen scope after the access mode is satisfied (open / PIN; approved
//! is gated on a remembered decision until the control channel lands). The
//! token-scoped routes `/v1/tracks`, `/v1/playlists`, `/v1/playlists/{id}`, and
//! `/v1/stream/{id}` (HTTP Range via `ServeFile`) then serve only what the
//! token's scope and permission allow. The listener is wrapped in TLS with a
//! per-host self-signed cert in [`crate::api::network`]; peers pin it via TOFU.
//!
//! Not yet built (roadmap, see `docs/STATUS.md`): download endpoints, the
//! transfer-log dashboard, and the WebSocket control / party channel.

use crate::db::{shares, tracks, transfer_log};
use crate::net::party::PartyState;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        ConnectInfo, FromRequestParts, Path, Request, State,
    },
    http::{
        header::{AUTHORIZATION, CONTENT_DISPOSITION},
        request::Parts,
        HeaderValue, StatusCode,
    },
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;
use tower::ServiceExt;
use tower_http::services::ServeFile;

/// Which shared scope a session token grants access to.
#[derive(Clone, Debug, PartialEq)]
pub enum Scope {
    Library,
    Playlist(i64),
}

/// An issued token's grant: the scope and whether downloads are permitted.
#[derive(Clone)]
pub struct Session {
    pub scope: Scope,
    pub can_download: bool,
    pub created_at_ms: i64,
    /// Peer IP (stable per device; revoke-by-peer keys on this).
    pub peer: String,
}

/// Host-side token store (token → grant). Cleared by a host "revoke all".
pub type Sessions = Arc<Mutex<HashMap<String, Session>>>;

/// Party-mode broadcast hub: fans the host's playback state out to connected
/// WebSocket peers, keeps the latest snapshot for new joiners, and tracks active.
#[derive(Clone)]
pub struct PartyHub {
    tx: broadcast::Sender<String>,
    latest: Arc<Mutex<Option<String>>>,
    active: Arc<AtomicBool>,
}

impl PartyHub {
    pub fn new() -> Self {
        let (tx, _rx) = broadcast::channel(16);
        Self {
            tx,
            latest: Arc::new(Mutex::new(None)),
            active: Arc::new(AtomicBool::new(false)),
        }
    }
    pub fn start(&self) {
        self.active.store(true, Ordering::Relaxed);
    }
    pub fn stop(&self) {
        self.active.store(false, Ordering::Relaxed);
        if let Ok(mut l) = self.latest.lock() {
            *l = None;
        }
        let _ = self.tx.send(r#"{"type":"ended"}"#.to_string());
    }
    pub fn is_active(&self) -> bool {
        self.active.load(Ordering::Relaxed)
    }
    /// Store + broadcast the latest playback snapshot to all party peers.
    pub fn broadcast_state(&self, state: &PartyState) {
        let payload = serde_json::json!({ "type": "state", "state": state });
        if let Ok(msg) = serde_json::to_string(&payload) {
            if let Ok(mut l) = self.latest.lock() {
                *l = Some(msg.clone());
            }
            let _ = self.tx.send(msg);
        }
    }
}

impl Default for PartyHub {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone)]
pub struct ServerConfig {
    pub db_path: PathBuf,
    pub name: String,
    pub host_id: String,
    pub fingerprint: String,
    pub sessions: Sessions,
    pub party: PartyHub,
}

impl ServerConfig {
    pub fn new(db_path: PathBuf, name: String, host_id: String, fingerprint: String) -> Self {
        Self {
            db_path,
            name,
            host_id,
            fingerprint,
            sessions: Arc::new(Mutex::new(HashMap::new())),
            party: PartyHub::new(),
        }
    }
}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[derive(Serialize)]
struct InfoResp {
    name: String,
    host_id: String,
    fingerprint: String,
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

fn track_dto(t: tracks::TrackRow) -> TrackDto {
    TrackDto {
        id: t.id,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration_ms: t.duration_ms,
    }
}

#[derive(Serialize)]
struct PlaylistDto {
    id: i64,
    name: String,
    track_count: i64,
}

#[derive(Serialize)]
struct ShareDto {
    /// `"library"` or `"playlist"`.
    scope: String,
    playlist_id: Option<i64>,
    label: String,
    mode: String,
    permission: String,
    requires_pin: bool,
}

pub fn router(cfg: ServerConfig) -> Router {
    Router::new()
        .route("/v1/info", get(info))
        .route("/v1/shares", get(list_shares))
        .route("/v1/auth/session", post(auth_session))
        .route("/v1/tracks", get(list_tracks))
        .route("/v1/playlists", get(list_playlists))
        .route("/v1/playlists/{id}", get(playlist_tracks))
        .route("/v1/stream/{id}", get(stream))
        .route("/v1/tracks/{id}/download", get(download))
        .route("/v1/tracks/{id}/meta", get(track_meta))
        .route("/v1/tracks/{id}/art", get(track_art))
        .route("/v1/party", get(party_ws))
        .with_state(cfg)
}

/// Run a closure with a fresh connection on a blocking thread. Returns `None` on
/// any error (handlers fail closed).
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

// ── Bearer-token auth extractor ──────────────────────────────────────────────

struct Auth(Session);

impl FromRequestParts<ServerConfig> for Auth {
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(
        parts: &mut Parts,
        state: &ServerConfig,
    ) -> Result<Self, Self::Rejection> {
        // Prefer the Authorization header; fall back to a `?token=` query param so
        // a plain stream URL (which the audio engine fetches without custom
        // headers) can still carry its scoped token.
        let header_token = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.strip_prefix("Bearer "))
            .map(str::to_owned);
        let token = header_token
            .or_else(|| {
                parts.uri.query().and_then(|q| {
                    q.split('&')
                        .find_map(|kv| kv.strip_prefix("token=").map(str::to_owned))
                })
            })
            .ok_or((StatusCode::UNAUTHORIZED, "missing bearer token"))?;
        state
            .sessions
            .lock()
            .ok()
            .and_then(|m| m.get(&token).cloned())
            .map(Auth)
            .ok_or((StatusCode::UNAUTHORIZED, "invalid or revoked token"))
    }
}

// ── Public endpoints ─────────────────────────────────────────────────────────

async fn info(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    Json(InfoResp {
        name: cfg.name.clone(),
        host_id: cfg.host_id.clone(),
        fingerprint: cfg.fingerprint.clone(),
        proto: 1,
    })
}

/// The shareable scopes + their access mode, so a peer's UI can decide whether to
/// prompt for a PIN before authenticating. Reveals labels only — never tracks.
async fn list_shares(State(cfg): State<ServerConfig>) -> impl IntoResponse {
    let rows = blocking_db(cfg.db_path.clone(), shares::list)
        .await
        .unwrap_or_default();
    let dtos: Vec<ShareDto> = rows
        .into_iter()
        .filter(|s| s.enabled)
        .map(|s| ShareDto {
            scope: if s.playlist_id.is_none() {
                "library".into()
            } else {
                "playlist".into()
            },
            playlist_id: s.playlist_id,
            label: s.label,
            mode: s.mode.clone(),
            permission: s.permission,
            requires_pin: s.mode == "pin",
        })
        .collect();
    Json(dtos)
}

#[derive(Deserialize)]
struct AuthReq {
    #[serde(default)]
    scope: String, // "library" | "playlist"
    #[serde(default)]
    playlist_id: Option<i64>,
    #[serde(default)]
    pin: Option<String>,
}

#[derive(Serialize)]
struct AuthResp {
    token: String,
}

async fn auth_session(
    State(cfg): State<ServerConfig>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(req): Json<AuthReq>,
) -> impl IntoResponse {
    let pid = if req.scope == "playlist" {
        req.playlist_id
    } else {
        None
    };
    let access = blocking_db(cfg.db_path.clone(), move |c| match pid {
        None => shares::library_access(c),
        Some(id) => shares::playlist_access(c, id),
    })
    .await
    .flatten();
    let Some(access) = access else {
        return (StatusCode::FORBIDDEN, "that scope is not shared").into_response();
    };

    match access.mode.as_str() {
        "open" => {}
        "pin" => {
            let provided = req.pin.as_deref().map(shares::hash_pin);
            let ok = matches!((&access.pin_hash, &provided), (Some(w), Some(g)) if w == g);
            if !ok {
                return (StatusCode::UNAUTHORIZED, "incorrect PIN").into_response();
            }
        }
        "approved" => {
            return (
                StatusCode::FORBIDDEN,
                "host approval required (not yet available)",
            )
                .into_response();
        }
        _ => return (StatusCode::FORBIDDEN, "unsupported share mode").into_response(),
    }

    let scope = match pid {
        Some(id) => Scope::Playlist(id),
        None => Scope::Library,
    };
    let token = uuid::Uuid::new_v4().simple().to_string();
    if let Ok(mut m) = cfg.sessions.lock() {
        m.insert(
            token.clone(),
            Session {
                scope,
                can_download: access.allows_download(),
                created_at_ms: now_ms(),
                peer: addr.ip().to_string(),
            },
        );
    }
    Json(AuthResp { token }).into_response()
}

// ── Token-scoped endpoints ───────────────────────────────────────────────────

async fn list_tracks(State(cfg): State<ServerConfig>, auth: Auth) -> impl IntoResponse {
    let scope = auth.0.scope.clone();
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        let songs = match scope {
            Scope::Library => tracks::browse_songs(c, 100_000, 0)?,
            Scope::Playlist(id) => shares::shared_playlist_tracks(c, id)?,
        };
        Ok(songs.into_iter().map(track_dto).collect::<Vec<_>>())
    })
    .await
    .unwrap_or_default();
    Json(rows)
}

async fn list_playlists(State(cfg): State<ServerConfig>, auth: Auth) -> impl IntoResponse {
    let scope = auth.0.scope.clone();
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        let pls = shares::shared_playlists(c)?;
        let pls = match scope {
            Scope::Library => pls,
            Scope::Playlist(id) => pls.into_iter().filter(|p| p.id == id).collect(),
        };
        Ok(pls
            .into_iter()
            .map(|p| PlaylistDto {
                id: p.id,
                name: p.name,
                track_count: p.track_count,
            })
            .collect::<Vec<_>>())
    })
    .await
    .unwrap_or_default();
    Json(rows)
}

async fn playlist_tracks(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
) -> impl IntoResponse {
    if let Scope::Playlist(pid) = auth.0.scope {
        if pid != id {
            return (StatusCode::FORBIDDEN, "out of scope").into_response();
        }
    }
    let rows = blocking_db(cfg.db_path.clone(), move |c| {
        // The playlist must actually be shared (covers the library-scope case).
        if !shares::shared_playlists(c)?.iter().any(|p| p.id == id) {
            return Ok(None);
        }
        Ok(Some(
            shares::shared_playlist_tracks(c, id)?
                .into_iter()
                .map(track_dto)
                .collect::<Vec<_>>(),
        ))
    })
    .await
    .flatten();
    match rows {
        Some(t) => Json(t).into_response(),
        None => (StatusCode::NOT_FOUND, "no such shared playlist").into_response(),
    }
}

/// Stream a track's original bytes if the token's scope covers it. `ServeFile`
/// honors HTTP Range (206 for seeking) and streams in chunks. The path is
/// resolved from the DB by id (never the request), so there is no path traversal.
async fn stream(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
    request: Request,
) -> impl IntoResponse {
    if !track_in_scope(&cfg, auth.0.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let Some(file_path) = track_path(&cfg, id).await else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    log_transfer(&cfg, &auth.0.peer, id, "stream");
    match ServeFile::new(&file_path).oneshot(request).await {
        Ok(resp) => resp.into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "file missing").into_response(),
    }
}

/// Whether the token's scope reaches `track_id` (library share → any track;
/// playlist scope → the track must belong to that playlist).
async fn track_in_scope(cfg: &ServerConfig, scope: Scope, track_id: i64) -> bool {
    blocking_db(cfg.db_path.clone(), move |c| {
        Ok(match scope {
            Scope::Library => shares::library_access(c)?.is_some(),
            Scope::Playlist(pid) => shares::track_in_playlist(c, pid, track_id)?,
        })
    })
    .await
    .unwrap_or(false)
}

async fn track_path(cfg: &ServerConfig, id: i64) -> Option<String> {
    blocking_db(cfg.db_path.clone(), move |c| {
        c.query_row("SELECT path FROM tracks WHERE id = ?1", [id], |r| {
            r.get::<_, String>(0)
        })
    })
    .await
}

/// Fire-and-forget activity log of a stream/download by `peer` (for the host's
/// connections dashboard). Best-effort: failures are ignored.
fn log_transfer(cfg: &ServerConfig, peer: &str, track_id: i64, kind: &'static str) {
    let db = cfg.db_path.clone();
    let peer = peer.to_string();
    tokio::spawn(async move {
        let _ = blocking_db(db, move |c| {
            transfer_log::record(c, &peer, track_id, kind, now_ms())
        })
        .await;
    });
}

/// Download a track's original file (gated on the share's download permission).
async fn download(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
    request: Request,
) -> impl IntoResponse {
    if !auth.0.can_download {
        return (
            StatusCode::FORBIDDEN,
            "downloads are not permitted for this share",
        )
            .into_response();
    }
    if !track_in_scope(&cfg, auth.0.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let Some(file_path) = track_path(&cfg, id).await else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    log_transfer(&cfg, &auth.0.peer, id, "download");
    let filename = std::path::Path::new(&file_path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("track")
        .replace(['"', '\\'], "");
    match ServeFile::new(&file_path).oneshot(request).await {
        Ok(mut resp) => {
            if let Ok(v) = HeaderValue::from_str(&format!("attachment; filename=\"{filename}\"")) {
                resp.headers_mut().insert(CONTENT_DISPOSITION, v);
            }
            resp.into_response()
        }
        Err(_) => (StatusCode::NOT_FOUND, "file missing").into_response(),
    }
}

#[derive(Serialize)]
struct MetaDto {
    id: i64,
    title: String,
    artist: String,
    album: String,
    duration_ms: i64,
    year: Option<i64>,
    has_art: bool,
    can_download: bool,
}

/// Full metadata for a single in-scope track (preview before streaming).
async fn track_meta(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
) -> impl IntoResponse {
    if !track_in_scope(&cfg, auth.0.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let can_download = auth.0.can_download;
    let meta = blocking_db(cfg.db_path.clone(), move |c| {
        Ok(tracks::track_by_id(c, id)?.map(|t| MetaDto {
            id: t.id,
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration_ms: t.duration_ms,
            year: t.year,
            has_art: t.art_path.is_some(),
            can_download,
        }))
    })
    .await
    .flatten();
    match meta {
        Some(m) => Json(m).into_response(),
        None => (StatusCode::NOT_FOUND, "no such track").into_response(),
    }
}

/// The album art bytes for an in-scope track (404 when the album has no art).
async fn track_art(
    State(cfg): State<ServerConfig>,
    Path(id): Path<i64>,
    auth: Auth,
    request: Request,
) -> impl IntoResponse {
    if !track_in_scope(&cfg, auth.0.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let art = blocking_db(cfg.db_path.clone(), move |c| {
        Ok(tracks::track_by_id(c, id)?.and_then(|t| t.art_path))
    })
    .await
    .flatten();
    let Some(art_path) = art else {
        return (StatusCode::NOT_FOUND, "no art").into_response();
    };
    match ServeFile::new(&art_path).oneshot(request).await {
        Ok(resp) => resp.into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "art missing").into_response(),
    }
}

// ── Party mode (WebSocket control channel) ───────────────────────────────────

/// Upgrade to a party WebSocket: the host fans its playback state out here and
/// answers clock-sync pings. No auth gate yet — party membership is open to LAN
/// peers who know the host (a session-token gate is a follow-up).
async fn party_ws(State(cfg): State<ServerConfig>, ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_party(socket, cfg))
}

async fn handle_party(mut socket: WebSocket, cfg: ServerConfig) {
    // Send the current snapshot immediately so a joiner can sync at once.
    if let Some(latest) = cfg.party.latest.lock().ok().and_then(|l| l.clone()) {
        if socket.send(Message::Text(latest.into())).await.is_err() {
            return;
        }
    }
    let mut rx = cfg.party.tx.subscribe();
    loop {
        tokio::select! {
            msg = rx.recv() => match msg {
                Ok(text) => {
                    if socket.send(Message::Text(text.into())).await.is_err() {
                        break;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => break,
            },
            incoming = socket.recv() => match incoming {
                Some(Ok(Message::Text(t))) => {
                    if let Some(reply) = party_reply(t.as_str()) {
                        if socket.send(Message::Text(reply.into())).await.is_err() {
                            break;
                        }
                    }
                }
                Some(Ok(Message::Close(_))) | None => break,
                Some(Err(_)) => break,
                _ => {}
            },
        }
    }
}

/// Answer a peer control message. Currently only clock-sync pings: echo `t0` and
/// stamp the host time `th` so the peer can compute its offset (Cristian).
fn party_reply(text: &str) -> Option<String> {
    let v: serde_json::Value = serde_json::from_str(text).ok()?;
    if v.get("type").and_then(|t| t.as_str()) == Some("ping") {
        let t0 = v.get("t0").and_then(|x| x.as_i64()).unwrap_or(0);
        return serde_json::to_string(
            &serde_json::json!({ "type": "pong", "t0": t0, "th": now_ms() }),
        )
        .ok();
    }
    None
}

/// Bind `0.0.0.0:0` and return a non-blocking std listener (for `axum_server`)
/// + the chosen port.
pub fn bind_std() -> std::io::Result<(std::net::TcpListener, u16)> {
    let listener = std::net::TcpListener::bind(("0.0.0.0", 0))?;
    let port = listener.local_addr()?.port();
    listener.set_nonblocking(true)?;
    Ok((listener, port))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::{playlists, Db};
    use axum::body::{to_bytes, Body};
    use axum::http::Request as HttpRequest;

    /// A temp db file seeded with `n` tracks; returns (path, track_ids).
    fn seed_db(n: i64) -> (PathBuf, Vec<i64>) {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("peerbeat_srv_{nanos}.db"));
        let db = Db::open(&path).unwrap();
        let mut ids = Vec::new();
        for i in 0..n {
            // a real file so /v1/stream can 200 for in-scope tracks
            let f = std::env::temp_dir().join(format!("peerbeat_srv_{nanos}_{i}.bin"));
            std::fs::write(&f, b"audio-bytes").unwrap();
            ids.push(
                upsert_track(
                    db.conn(),
                    &NewTrack {
                        path: f.to_string_lossy().into_owned(),
                        normalized_path: f.to_string_lossy().into_owned(),
                        title: format!("Song {i}"),
                        added_at: 1,
                        ..Default::default()
                    },
                )
                .unwrap(),
            );
        }
        (path, ids)
    }

    fn run<F: std::future::Future>(f: F) -> F::Output {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(f)
    }

    async fn status_of(cfg: &ServerConfig, req: HttpRequest<Body>) -> StatusCode {
        router(cfg.clone()).oneshot(req).await.unwrap().status()
    }

    async fn token_for(cfg: &ServerConfig, body: &str) -> Option<String> {
        let req = HttpRequest::post("/v1/auth/session")
            .header("content-type", "application/json")
            .extension(ConnectInfo(SocketAddr::from(([127, 0, 0, 1], 9999))))
            .body(Body::from(body.to_string()))
            .unwrap();
        let resp = router(cfg.clone()).oneshot(req).await.unwrap();
        if resp.status() != StatusCode::OK {
            return None;
        }
        let bytes = to_bytes(resp.into_body(), usize::MAX).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        v.get("token").and_then(|t| t.as_str()).map(str::to_owned)
    }

    #[test]
    fn open_library_share_requires_token_then_serves() {
        run(async {
            let (path, ids) = seed_db(2);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            shares::set_share(
                &Connection::open(&cfg.db_path).unwrap(),
                None,
                "stream",
                "open",
                None,
                true,
            )
            .unwrap();

            // /v1/tracks without a token → 401
            let unauth = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks").body(Body::empty()).unwrap(),
            )
            .await;
            assert_eq!(unauth, StatusCode::UNAUTHORIZED);

            // authenticate to the library scope (open → no pin)
            let token = token_for(&cfg, r#"{"scope":"library"}"#).await.unwrap();

            // /v1/tracks with the token → 200
            let ok = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks")
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(ok, StatusCode::OK);

            // an invalid token → 401
            let bad = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks")
                    .header("authorization", "Bearer nope")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(bad, StatusCode::UNAUTHORIZED);

            // streaming an in-scope track succeeds (real temp file)
            let streamed = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(streamed, StatusCode::OK);

            // streaming via a `?token=` query param (no auth header) also works
            let streamed_q = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}?token={token}", ids[1]))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(streamed_q, StatusCode::OK);
        });
    }

    #[test]
    fn pin_share_enforces_pin_and_playlist_scope() {
        run(async {
            let (path, ids) = seed_db(2);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            let c = Connection::open(&cfg.db_path).unwrap();
            let p = playlists::create(&c, "Shared", 1).unwrap();
            playlists::add_tracks(&c, p, &[ids[0]], 2).unwrap(); // only track 0 is in the playlist
            shares::set_share(&c, Some(p), "stream", "pin", Some("4242"), true).unwrap();

            // wrong / missing pin → 401
            assert!(token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p}}}"#)
            )
            .await
            .is_none());
            assert!(token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p},"pin":"0000"}}"#)
            )
            .await
            .is_none());

            // correct pin → token scoped to the playlist
            let token = token_for(
                &cfg,
                &format!(r#"{{"scope":"playlist","playlist_id":{p},"pin":"4242"}}"#),
            )
            .await
            .unwrap();

            // in-playlist track streams; out-of-playlist track is 403
            let in_scope = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(in_scope, StatusCode::OK);

            let out_scope = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[1]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(out_scope, StatusCode::FORBIDDEN);
        });
    }

    #[test]
    fn download_requires_download_permission_and_meta_works() {
        run(async {
            let (path, ids) = seed_db(1);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            let c = Connection::open(&cfg.db_path).unwrap();

            // stream-only library share
            shares::set_share(&c, None, "stream", "open", None, true).unwrap();
            let token = token_for(&cfg, r#"{"scope":"library"}"#).await.unwrap();

            // metadata preview works for an in-scope track
            let meta = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/tracks/{}/meta", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(meta, StatusCode::OK);

            // download is forbidden under a stream-only share
            let dl = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/tracks/{}/download", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(dl, StatusCode::FORBIDDEN);

            // upgrading the share to stream+download lets a fresh token download
            shares::set_share(&c, None, "stream_download", "open", None, true).unwrap();
            let token2 = token_for(&cfg, r#"{"scope":"library"}"#).await.unwrap();
            let dl2 = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/tracks/{}/download", ids[0]))
                    .header("authorization", format!("Bearer {token2}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(dl2, StatusCode::OK);
        });
    }
}
