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
//! Auth hardening: session tokens carry an absolute TTL and are swept/rejected on
//! expiry; `/v1/auth/session` is per-IP rate-limited against PIN brute-force; PINs
//! are stored Argon2id-hashed; and the `/v1/party` WebSocket is token-gated (and
//! re-checked live) so a revoke tears down in-flight party connections.

use crate::db::{remembered_peers, shares, tracks, transfer_log};
use crate::net::party::PartyState;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        ConnectInfo, FromRequestParts, Path, Request, State,
    },
    http::{
        header::{AUTHORIZATION, CONTENT_DISPOSITION, RETRY_AFTER},
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
use std::net::{IpAddr, SocketAddr};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
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
    /// Absolute expiry (ms since epoch). The `Auth` extractor rejects + drops a
    /// token past this; party sockets re-check it so a revoke tears down live ones.
    pub expires_at_ms: i64,
    /// Peer IP (stable per device; revoke-by-peer keys on this).
    pub peer: String,
}

/// Host-side token store (token → grant). Cleared by a host "revoke all".
pub type Sessions = Arc<Mutex<HashMap<String, Session>>>;

/// How long an issued session token stays valid (12h — long enough for a
/// listening session, short enough that a leaked token doesn't live forever).
const TOKEN_TTL_MS: i64 = 12 * 60 * 60 * 1000;

/// Auth brute-force guard: max failed attempts per peer IP inside the window.
const AUTH_WINDOW_MS: i64 = 60_000;
const AUTH_MAX_FAILS: u32 = 5;

/// Per-IP failed-auth counter (fixed window). Successful auth clears the entry.
/// Only PIN mismatches count, so legitimate open-share peers are never throttled.
#[derive(Default)]
pub struct RateLimiter {
    inner: Mutex<HashMap<IpAddr, (i64, u32)>>, // ip → (window_start_ms, fails)
}

impl RateLimiter {
    /// `Some(retry_after_secs)` if `ip` is currently blocked, else `None`.
    fn blocked_for(&self, ip: IpAddr, now: i64) -> Option<i64> {
        let g = self.inner.lock().ok()?;
        let (start, fails) = g.get(&ip).copied()?;
        if now - start < AUTH_WINDOW_MS && fails >= AUTH_MAX_FAILS {
            Some(((start + AUTH_WINDOW_MS - now) / 1000).max(1))
        } else {
            None
        }
    }
    fn record_failure(&self, ip: IpAddr, now: i64) {
        if let Ok(mut g) = self.inner.lock() {
            let e = g.entry(ip).or_insert((now, 0));
            if now - e.0 >= AUTH_WINDOW_MS {
                *e = (now, 0); // window rolled over
            }
            e.1 += 1;
        }
    }
    fn record_success(&self, ip: IpAddr) {
        if let Ok(mut g) = self.inner.lock() {
            g.remove(&ip);
        }
    }
}

/// One peer's pending connection request under the "approved peers" share mode.
/// The peer polls `/v1/auth/session` with its `challenge` until the host decides.
#[derive(Clone)]
pub struct PendingApproval {
    pub challenge: String,
    pub peer: String,
    pub scope: Scope,
    pub can_download: bool,
    pub label: String,
    pub requested_at_ms: i64,
    /// `None` = awaiting host, `Some(true/false)` = allowed / denied.
    pub decision: Option<bool>,
}

/// Host-side queue of pending approval requests (shared with the FRB API so the
/// host UI can list them and post allow/deny decisions).
pub type Approvals = Arc<Mutex<Vec<PendingApproval>>>;

/// How long a pending/decided approval lingers before it is swept (peer must
/// finish its poll within this window).
const APPROVAL_TTL_MS: i64 = 5 * 60 * 1000;

/// A peer's request for the host to play a specific (host) track during a party.
#[derive(Clone)]
pub struct PartyRequest {
    pub peer: String,
    pub track_id: i64,
    pub at_ms: i64,
}

/// Party-mode broadcast hub: fans the host's playback state out to connected
/// WebSocket peers, keeps the latest snapshot for new joiners, and tracks active.
#[derive(Clone)]
pub struct PartyHub {
    tx: broadcast::Sender<String>,
    latest: Arc<Mutex<Option<String>>>,
    active: Arc<AtomicBool>,
    /// Pending peer "play this" requests, drained by the host UI.
    requests: Arc<Mutex<Vec<PartyRequest>>>,
}

impl PartyHub {
    pub fn new() -> Self {
        let (tx, _rx) = broadcast::channel(16);
        Self {
            tx,
            latest: Arc::new(Mutex::new(None)),
            active: Arc::new(AtomicBool::new(false)),
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Record a peer's track request (capped so a flooding peer can't grow it
    /// unbounded). Newest-last.
    pub fn record_request(&self, peer: String, track_id: i64) {
        if let Ok(mut q) = self.requests.lock() {
            if q.len() >= 64 {
                q.remove(0);
            }
            q.push(PartyRequest {
                peer,
                track_id,
                at_ms: now_ms(),
            });
        }
    }

    /// Take and clear all pending requests (for the host UI).
    pub fn drain_requests(&self) -> Vec<PartyRequest> {
        self.requests
            .lock()
            .map(|mut q| std::mem::take(&mut *q))
            .unwrap_or_default()
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
    pub auth_limiter: Arc<RateLimiter>,
    pub approvals: Approvals,
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
            auth_limiter: Arc::new(RateLimiter::default()),
            approvals: Arc::new(Mutex::new(Vec::new())),
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

struct Auth {
    session: Session,
    /// The bearer token itself, so long-lived consumers (party socket) can
    /// re-check that it is still present + unexpired while they run.
    token: String,
}

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
        let now = now_ms();
        let mut map = state
            .sessions
            .lock()
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "session store poisoned"))?;
        match map.get(&token) {
            Some(s) if s.expires_at_ms > now => {
                let session = s.clone();
                drop(map);
                Ok(Auth { session, token })
            }
            Some(_) => {
                map.remove(&token); // expired → drop it
                Err((StatusCode::UNAUTHORIZED, "session expired"))
            }
            None => Err((StatusCode::UNAUTHORIZED, "invalid or revoked token")),
        }
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
    /// Poll handle for the approved-peers flow (echoed back from the first 202).
    #[serde(default)]
    challenge: Option<String>,
}

#[derive(Serialize)]
struct AuthResp {
    token: String,
}

/// Issue + store a scoped session token (with TTL), sweeping expired ones.
fn mint_token(
    cfg: &ServerConfig,
    scope: Scope,
    can_download: bool,
    ip: IpAddr,
    now: i64,
) -> String {
    let token = uuid::Uuid::new_v4().simple().to_string();
    if let Ok(mut m) = cfg.sessions.lock() {
        m.retain(|_, s| s.expires_at_ms > now); // opportunistic sweep of expired tokens
        m.insert(
            token.clone(),
            Session {
                scope,
                can_download,
                created_at_ms: now,
                expires_at_ms: now + TOKEN_TTL_MS,
                peer: ip.to_string(),
            },
        );
    }
    token
}

/// Display label for a scope (for the host's approval prompt).
async fn scope_label(cfg: &ServerConfig, scope: &Scope) -> String {
    match scope {
        Scope::Library => "Whole library".to_string(),
        Scope::Playlist(id) => {
            let id = *id;
            blocking_db(cfg.db_path.clone(), move |c| {
                c.query_row("SELECT name FROM playlists WHERE id = ?1", [id], |r| {
                    r.get::<_, String>(0)
                })
            })
            .await
            .unwrap_or_else(|| format!("Playlist {id}"))
        }
    }
}

/// The "approved peers" handshake: honor a remembered decision, otherwise create
/// (or poll) a pending request the host resolves from its UI. Returns 200 (token)
/// / 202 (still pending, with the `challenge`) / 403 (denied or expired).
async fn handle_approved(
    cfg: &ServerConfig,
    req: &AuthReq,
    ip: IpAddr,
    now: i64,
    scope: Scope,
    can_download: bool,
) -> axum::response::Response {
    let peer = ip.to_string();

    // 1. A remembered allow/deny short-circuits the prompt.
    let host_id = cfg.host_id.clone();
    let remembered = {
        let peer = peer.clone();
        blocking_db(cfg.db_path.clone(), move |c| {
            remembered_peers::decision(c, &host_id, &peer)
        })
        .await
        .flatten()
    };
    match remembered {
        Some(false) => {
            return (StatusCode::FORBIDDEN, "this device was denied by the host").into_response()
        }
        Some(true) => {
            let token = mint_token(cfg, scope, can_download, ip, now);
            return Json(AuthResp { token }).into_response();
        }
        None => {}
    }

    // 2. Interactive flow.
    let label = scope_label(cfg, &scope).await;
    let Ok(mut g) = cfg.approvals.lock() else {
        return (StatusCode::INTERNAL_SERVER_ERROR, "approval store").into_response();
    };
    g.retain(|p| now - p.requested_at_ms < APPROVAL_TTL_MS); // drop stale entries

    if let Some(ch) = req.challenge.as_deref() {
        // Peer polling an existing challenge.
        let Some(i) = g.iter().position(|p| p.challenge == ch && p.peer == peer) else {
            return (StatusCode::FORBIDDEN, "approval request expired").into_response();
        };
        match g[i].decision {
            Some(true) => {
                let p = g.remove(i);
                drop(g);
                let token = mint_token(cfg, p.scope, p.can_download, ip, now);
                Json(AuthResp { token }).into_response()
            }
            Some(false) => {
                g.remove(i);
                (StatusCode::FORBIDDEN, "the host denied your request").into_response()
            }
            None => (
                StatusCode::ACCEPTED,
                Json(serde_json::json!({ "challenge": ch })),
            )
                .into_response(),
        }
    } else {
        // New request — reuse any in-flight one for the same peer+scope.
        if let Some(p) = g
            .iter()
            .find(|p| p.peer == peer && p.scope == scope && p.decision.is_none())
        {
            let ch = p.challenge.clone();
            return (
                StatusCode::ACCEPTED,
                Json(serde_json::json!({ "challenge": ch })),
            )
                .into_response();
        }
        let challenge = uuid::Uuid::new_v4().simple().to_string();
        g.push(PendingApproval {
            challenge: challenge.clone(),
            peer,
            scope,
            can_download,
            label,
            requested_at_ms: now,
            decision: None,
        });
        (
            StatusCode::ACCEPTED,
            Json(serde_json::json!({ "challenge": challenge })),
        )
            .into_response()
    }
}

async fn auth_session(
    State(cfg): State<ServerConfig>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    Json(req): Json<AuthReq>,
) -> impl IntoResponse {
    let ip = addr.ip();
    let now = now_ms();

    // Brute-force guard: a peer that has burned through its failed-attempt budget
    // is told to back off (429 + Retry-After) before we even touch the PIN.
    if let Some(retry) = cfg.auth_limiter.blocked_for(ip, now) {
        let mut resp = (StatusCode::TOO_MANY_REQUESTS, "too many attempts").into_response();
        if let Ok(v) = HeaderValue::from_str(&retry.to_string()) {
            resp.headers_mut().insert(RETRY_AFTER, v);
        }
        return resp;
    }

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

    let scope = match pid {
        Some(id) => Scope::Playlist(id),
        None => Scope::Library,
    };
    let can_download = access.allows_download();

    match access.mode.as_str() {
        "open" => {}
        "pin" => {
            let ok = match (&access.pin_hash, req.pin.as_deref()) {
                (Some(stored), Some(p)) => shares::verify_pin(stored, p),
                _ => false,
            };
            if !ok {
                cfg.auth_limiter.record_failure(ip, now);
                return (StatusCode::UNAUTHORIZED, "incorrect PIN").into_response();
            }
        }
        "approved" => {
            return handle_approved(&cfg, &req, ip, now, scope, can_download).await;
        }
        _ => return (StatusCode::FORBIDDEN, "unsupported share mode").into_response(),
    }

    let token = mint_token(&cfg, scope, can_download, ip, now);
    cfg.auth_limiter.record_success(ip);
    Json(AuthResp { token }).into_response()
}

// ── Token-scoped endpoints ───────────────────────────────────────────────────

async fn list_tracks(State(cfg): State<ServerConfig>, auth: Auth) -> impl IntoResponse {
    let scope = auth.session.scope.clone();
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
    let scope = auth.session.scope.clone();
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
    if let Scope::Playlist(pid) = auth.session.scope {
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
    if !track_in_scope(&cfg, auth.session.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let Some(file_path) = track_path(&cfg, id).await else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    log_transfer(&cfg, &auth.session.peer, id, "stream");
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
    if !auth.session.can_download {
        return (
            StatusCode::FORBIDDEN,
            "downloads are not permitted for this share",
        )
            .into_response();
    }
    if !track_in_scope(&cfg, auth.session.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let Some(file_path) = track_path(&cfg, id).await else {
        return (StatusCode::NOT_FOUND, "no such track").into_response();
    };
    log_transfer(&cfg, &auth.session.peer, id, "download");
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
    if !track_in_scope(&cfg, auth.session.scope.clone(), id).await {
        return (StatusCode::FORBIDDEN, "track not in your shared scope").into_response();
    }
    let can_download = auth.session.can_download;
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
    if !track_in_scope(&cfg, auth.session.scope.clone(), id).await {
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

/// Upgrade to a party WebSocket. Auth-gated: the `Auth` extractor runs before the
/// upgrade, so a peer without a valid (unexpired) session token is rejected 401 —
/// this closes the pre-hardening hole where any LAN device could read the host's
/// now-playing state. The token is re-checked while the socket runs so a host
/// "revoke" (or token expiry) tears the live connection down.
async fn party_ws(
    State(cfg): State<ServerConfig>,
    auth: Auth,
    ws: WebSocketUpgrade,
) -> impl IntoResponse {
    let token = auth.token;
    ws.on_upgrade(move |socket| handle_party(socket, cfg, token))
}

/// True while `token` is still a live, unexpired session.
fn token_live(cfg: &ServerConfig, token: &str) -> bool {
    cfg.sessions
        .lock()
        .ok()
        .map(|m| {
            m.get(token)
                .map(|s| s.expires_at_ms > now_ms())
                .unwrap_or(false)
        })
        .unwrap_or(false)
}

async fn handle_party(mut socket: WebSocket, cfg: ServerConfig, token: String) {
    // The peer's stable identity (IP) for any requests it makes.
    let peer = cfg
        .sessions
        .lock()
        .ok()
        .and_then(|m| m.get(&token).map(|s| s.peer.clone()))
        .unwrap_or_default();
    // Send the current snapshot immediately so a joiner can sync at once.
    if let Some(latest) = cfg.party.latest.lock().ok().and_then(|l| l.clone()) {
        if socket.send(Message::Text(latest.into())).await.is_err() {
            return;
        }
    }
    let mut rx = cfg.party.tx.subscribe();
    // Periodic liveness check so a revoked / expired token drops the socket even
    // when the host isn't actively broadcasting.
    let mut revalidate = tokio::time::interval(Duration::from_secs(5));
    loop {
        tokio::select! {
            _ = revalidate.tick() => {
                if !token_live(&cfg, &token) {
                    break;
                }
            }
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
                    if let Some(track_id) = parse_request(t.as_str()) {
                        cfg.party.record_request(peer.clone(), track_id);
                    } else if let Some(reply) = party_reply(t.as_str()) {
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

/// Parse a peer's `{"type":"request","track_id":N}` message → the requested
/// host track id, if that's what it is.
fn parse_request(text: &str) -> Option<i64> {
    let v: serde_json::Value = serde_json::from_str(text).ok()?;
    if v.get("type").and_then(|t| t.as_str()) == Some("request") {
        return v.get("track_id").and_then(|x| x.as_i64());
    }
    None
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

    #[test]
    fn expired_token_is_rejected_and_dropped() {
        run(async {
            let (path, _ids) = seed_db(1);
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
            // Inject an already-expired token straight into the store.
            let token = "expiredtoken".to_string();
            cfg.sessions.lock().unwrap().insert(
                token.clone(),
                Session {
                    scope: Scope::Library,
                    can_download: false,
                    created_at_ms: 0,
                    expires_at_ms: 1, // long past
                    peer: "127.0.0.1".into(),
                },
            );
            let status = status_of(
                &cfg,
                HttpRequest::get("/v1/tracks")
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(status, StatusCode::UNAUTHORIZED);
            // The extractor also evicts the dead token.
            assert!(cfg.sessions.lock().unwrap().get(&token).is_none());
        });
    }

    #[test]
    fn auth_rate_limits_after_repeated_bad_pins() {
        run(async {
            let (path, _ids) = seed_db(1);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            shares::set_share(
                &Connection::open(&cfg.db_path).unwrap(),
                None,
                "stream",
                "pin",
                Some("4242"),
                true,
            )
            .unwrap();
            let bad = || {
                HttpRequest::post("/v1/auth/session")
                    .header("content-type", "application/json")
                    .extension(ConnectInfo(SocketAddr::from(([127, 0, 0, 1], 5000))))
                    .body(Body::from(
                        r#"{"scope":"library","pin":"0000"}"#.to_string(),
                    ))
                    .unwrap()
            };
            for _ in 0..AUTH_MAX_FAILS {
                assert_eq!(status_of(&cfg, bad()).await, StatusCode::UNAUTHORIZED);
            }
            // Budget spent → throttled before the PIN is even checked.
            assert_eq!(status_of(&cfg, bad()).await, StatusCode::TOO_MANY_REQUESTS);
        });
    }

    #[test]
    fn party_parse_record_and_drain_requests() {
        // message parsing
        assert_eq!(
            parse_request(r#"{"type":"request","track_id":42}"#),
            Some(42)
        );
        assert_eq!(parse_request(r#"{"type":"ping","t0":1}"#), None);
        assert_eq!(parse_request("not json"), None);

        // record + drain (drain clears)
        let hub = PartyHub::new();
        assert!(hub.drain_requests().is_empty());
        hub.record_request("1.2.3.4".into(), 7);
        hub.record_request("1.2.3.4".into(), 9);
        let reqs = hub.drain_requests();
        assert_eq!(reqs.len(), 2);
        assert_eq!(reqs[0].track_id, 7);
        assert_eq!(reqs[1].track_id, 9);
        assert!(hub.drain_requests().is_empty());
    }

    #[test]
    fn party_ws_requires_token() {
        run(async {
            let (path, _ids) = seed_db(1);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            // No token → 401 (Auth extractor runs before the WS upgrade).
            let s = status_of(
                &cfg,
                HttpRequest::get("/v1/party").body(Body::empty()).unwrap(),
            )
            .await;
            assert_eq!(s, StatusCode::UNAUTHORIZED);
        });
    }

    #[test]
    fn approved_mode_pends_then_allow_issues_token() {
        run(async {
            let (path, ids) = seed_db(1);
            let cfg = ServerConfig::new(path, "Host".into(), "h".into(), "fp".into());
            shares::set_share(
                &Connection::open(&cfg.db_path).unwrap(),
                None,
                "stream",
                "approved",
                None,
                true,
            )
            .unwrap();

            let new_req = |challenge: Option<&str>| {
                let body = match challenge {
                    Some(ch) => format!(r#"{{"scope":"library","challenge":"{ch}"}}"#),
                    None => r#"{"scope":"library"}"#.to_string(),
                };
                HttpRequest::post("/v1/auth/session")
                    .header("content-type", "application/json")
                    .extension(ConnectInfo(SocketAddr::from(([127, 0, 0, 1], 6000))))
                    .body(Body::from(body))
                    .unwrap()
            };

            // First contact → 202 Accepted + a challenge.
            let resp = router(cfg.clone()).oneshot(new_req(None)).await.unwrap();
            assert_eq!(resp.status(), StatusCode::ACCEPTED);
            let bytes = to_bytes(resp.into_body(), usize::MAX).await.unwrap();
            let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
            let challenge = v["challenge"].as_str().unwrap().to_string();

            // Still pending → polling returns 202 again.
            let pend = router(cfg.clone())
                .oneshot(new_req(Some(&challenge)))
                .await
                .unwrap();
            assert_eq!(pend.status(), StatusCode::ACCEPTED);

            // Host allows it.
            cfg.approvals
                .lock()
                .unwrap()
                .iter_mut()
                .find(|p| p.challenge == challenge)
                .unwrap()
                .decision = Some(true);

            // Poll → 200 + token, and the token actually streams an in-scope track.
            let ok = router(cfg.clone())
                .oneshot(new_req(Some(&challenge)))
                .await
                .unwrap();
            assert_eq!(ok.status(), StatusCode::OK);
            let bytes = to_bytes(ok.into_body(), usize::MAX).await.unwrap();
            let token = serde_json::from_slice::<serde_json::Value>(&bytes).unwrap()["token"]
                .as_str()
                .unwrap()
                .to_string();
            let streamed = status_of(
                &cfg,
                HttpRequest::get(format!("/v1/stream/{}", ids[0]))
                    .header("authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await;
            assert_eq!(streamed, StatusCode::OK);
        });
    }
}
