# PeerBeat — Security

PeerBeat's threat model is a **shared local network** (home / café / dorm
Wi-Fi). Goals: traffic is encrypted even on an untrusted LAN; a host controls
exactly who reaches its library and can revoke instantly; nothing leaves the
LAN. It is explicitly *not* designed to be exposed to the internet.

## Transport encryption + TOFU pinning

- Each host generates a self-signed certificate (`rcgen`) at first run and
  persists the cert+key+fingerprint (`net/tls.rs`). All traffic is TLS (rustls
  with the `ring` provider).
- There is no CA. Instead, **trust on first use**: the first time a peer
  connects, it pins the host's certificate SHA-256 (`known_hosts.spki_sha256`,
  via `net/tofu.dart`). On later connections a changed fingerprint is **refused**
  — protecting against a mid-session MITM swapping certs.
- The pin is only committed *after* the response validates as a genuine PeerBeat
  reply, so a first-use impostor returning garbage can't lock in a cert.

## Access modes (per share)

A host marks playlists (or the whole library) shareable, each with a mode:

- **Open** — anyone on the LAN may connect.
- **PIN** — a 4–6 digit code. PINs are stored **Argon2id-hashed** (PHC string
  with a per-PIN salt; `db/shares.rs`), never in clear. A slow KDF + per-IP rate
  limiting on `/v1/auth/session` (429 + `Retry-After`) makes guessing
  expensive. Pre-hardening SHA-256 PINs no longer verify, forcing a one-time
  re-entry after upgrade.
- **Approved peers** — the host gets an Allow / Always-allow / Deny prompt for
  each new peer; "always" decisions are remembered (`remembered_peers`).

Each share also carries a **permission**: `stream` (stream only) or
`stream_download` (stream + download). The download route returns `403` when the
share is stream-only.

## Session tokens

- Authenticating to a scope mints a random bearer token scoped to that share,
  with a **12-hour absolute TTL**. Expired tokens are swept and rejected.
- Tokens are stored **as SHA-256 digests** in the host's in-memory session map —
  a memory scrape yields digests, not usable tokens. Tokens never touch disk.
- "Revoke all access" clears the session map immediately; the party WebSocket
  re-checks token validity every ~5 s, so a revoke also drops live party
  sockets.

## Server hardening

- **No path traversal.** File routes resolve a track *id* to a path through a DB
  query — client input never reaches the filesystem.
- **Scope enforcement.** Every token is checked against the share scope before a
  track is streamed/downloaded.
- **Header-injection defence.** The download `Content-Disposition` filename is
  stripped of quotes, backslashes, and control characters.
- **Resource bounds.** The party request queue is capped (overflow is logged);
  the stream cache is size-capped and swept on startup. *(A per-peer byte-rate
  limit on streaming is tracked for the RC hardening pass — see
  [`STATUS.md`](STATUS.md).)*

## Local data at rest

The SQLite store and album-art cache are unencrypted local files (same trust
level as the user's music files themselves). Secrets are minimized: PINs are
hashed, tokens are memory-only digests, and there are no third-party
credentials because there are no third-party services.

## Out of scope

No internet exposure, no NAT traversal, no relay. PeerBeat assumes peers are on
the same trusted-ish LAN segment; it secures the *traffic* on that segment, not
remote access.
