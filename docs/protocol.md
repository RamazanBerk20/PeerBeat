# PeerBeat — LAN Wire Protocol

Everything here is **local-network only**. There is no cloud, no account, no
relay. A host serves; peers pull. Transport is **TLS 1.3** on a single port that
carries both the REST API and the WebSocket control channel.

- Service type (mDNS/DNS-SD): `_peerbeat._tcp`
- API base: `https://<host>:<port>/v1`
- Protocol version: `1` (sent in `info`, the mDNS TXT record, and the WS hello)

## 1. Discovery

Hosts advertise via `mdns-sd` with TXT records:

| key | value |
|-----|-------|
| `id` | stable host id (random, persisted) |
| `name` | user display name |
| `color` | avatar accent (hex) |
| `proto` | protocol version |
| `fp` | first 8 bytes of the cert SPKI SHA-256 (hex) — short hint only |
| `auth` | `open` \| `pin` \| `approved` |

Peers browse the same type to populate the Network screen. **Fallbacks** when
mDNS is blocked (client-isolation Wi-Fi, VPNs, Android multicast limits):

- **Manual** `host:port` entry.
- **QR pairing** — the host shows a QR encoding `peerbeat://<host>:<port>/<full
  SPKI fingerprint>`; scanning bootstraps the pin out-of-band (MITM-resistant
  from first contact).

## 2. TLS & trust (TOFU)

Each host generates a self-signed certificate (`rcgen`) once and persists it.
Peers **pin the SHA-256 of the certificate's SPKI** (public key), not the whole
cert, on first connection (so the host can rotate the cert without re-pinning).

- First sight → show the fingerprint, store the pin after the user proceeds
  (or automatically if QR-paired, since the QR carried the full fingerprint).
- Later mismatch → **hard fail** with a prominent MITM warning; never auto-trust.
- The fingerprint is shown in both peers' UIs for optional verbal verification.

## 3. Authentication

A peer obtains a **session bearer token** before streaming/downloading. The token
is bound to the pinned fingerprint and scoped to the shares it was granted;
preview endpoints (metadata/art) are readable by any pinned peer without a token.

```
POST /v1/auth/session
  body: { "peerId": "...", "name": "...", "color": "#...", "pin": "1234"? }
  → 200 { "token": "...", "expiresAt": <ms>, "shares": [<shareId>...] }
  → 401 (bad/again PIN)   → 403 (denied)   → 202 (approval pending, then WS push)
```

- **Open**: token issued immediately.
- **PIN**: one 4–6 digit PIN per host session; verified once, then the token
  carries the grant.
- **Approved**: host is prompted to allow/deny (remembered per peer); until then
  `202` and the decision arrives over the WS control channel.

`Authorization: Bearer <token>` is sent on stream/download requests and in the WS
hello frame. **Revoke** (host one-tap) invalidates the token immediately.

## 4. REST API

| method · path | auth | purpose |
|---|---|---|
| `GET /v1/info` | none | host id, name, color, proto, auth mode, capabilities (codecs, transcode?) |
| `GET /v1/playlists` | token | shareable playlists `[ {id, name, trackCount, permission} ]` |
| `GET /v1/playlists/{id}` | token | track list with metadata |
| `GET /v1/tracks/{id}/meta` | pinned | full metadata (preview before streaming) |
| `GET /v1/tracks/{id}/art` | pinned | album art bytes (preview) |
| `GET /v1/tracks/{id}/stream` | token | audio bytes, **HTTP Range** (`206`) |
| `GET /v1/playlists/{id}/download` | token (stream_download) | ZIP of tracks, each with embedded tags + cover |
| `GET /v1/tracks/{id}/download` | token (stream_download) | single file with tags + cover |

`{id}` is the **content hash**, so a peer's download dedups against tracks it
already has and party-mode can match tracks across libraries.

### Streaming details

- `Accept-Ranges: bytes`; the server honours `Range:` and replies `206` with
  `Content-Range` — this is what makes seek/scrub on a remote stream cheap.
- **Original bytes by default** (no transcode) when the peer's `/info` codec list
  covers the track. **Transcode** is best-effort and **desktop-host only**
  (symphonia/ffmpeg), negotiated via a `?codec=` hint; if a host can't transcode
  an unsupported codec it returns `415` and the peer falls back to download.
- Per-peer concurrency + bandwidth caps; every stream/download is written to
  `transfer_log` for the host's live dashboard and one-tap revoke.

## 5. WebSocket control channel (`/v1/ws`)

JSON frames, `{ "type": ..., ... }`. Used for presence, host events, and party
mode. After upgrade the peer sends:

```json
{ "type": "hello", "token": "...", "proto": 1 }
```

Server → peer events:

- `{ "type": "peers", "peers": [ {id, name, color} ] }` — connected peers list
  (only if the host enabled "peers can see each other").
- `{ "type": "approval", "granted": true }` — Approved-mode decision.
- `{ "type": "revoked" }` — access revoked; peer must stop.
- `{ "type": "share-changed", ... }` — a share was added/removed/permission-changed.

## 6. Party mode

A **separate session role** layered on the control channel; clearly distinct from
independent pull-streaming (where each peer plays whatever it wants).

### Clock sync (Cristian / NTP-style)

```
peer → host : { "type":"ping", "t0":<peerMono> }
host → peer : { "type":"pong", "t0":<echo>, "t1":<hostRecv>, "t2":<hostSend> }
peer        : t3 = now
  offset = ((t1 - t0) + (t2 - t3)) / 2
  rtt    = (t3 - t0) - (t2 - t1)
```

Samples with RTT above a rolling threshold are discarded; the min-RTT sample's
offset is kept and smoothed with an EWMA. Re-sync every ~5 s and on network
change.

### Synchronized playback

```
host → all : { "type":"party-state",
               "trackId":"<hash>", "hostStartTs":<hostMono>, "posMs":<n>,
               "paused":false }
```

Each peer maps `hostStartTs` into its own clock via `offset` and schedules
play/seek so playback position matches. If measured drift exceeds ~80 ms a peer
nudges rate or micro-seeks to converge — keeping the room within the **~100 ms**
budget. Party peers that lack the track locally pull-stream it from the host in
parallel.

- **Host controls** playback for everyone.
- Peers may **request** tracks only if the host enabled requests
  (`{ "type":"request", "trackId":"..." }` → host queue).

## 7. Error model

Standard HTTP status + `{ "error": "code", "message": "..." }`. Codes include
`unauthorized`, `forbidden`, `pin_required`, `pin_invalid`, `approval_pending`,
`not_shared`, `revoked`, `unsupported_codec`, `rate_limited`.
