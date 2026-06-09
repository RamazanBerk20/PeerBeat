# PeerBeat — Privacy

**PeerBeat is offline-first and local-only.** No accounts, no cloud, no
telemetry, no analytics, no third-party streaming services, and no internet
connection is ever required. The only network traffic PeerBeat originates is on
your **local network**, and only when you opt into LAN sharing.

## Everything stored (on your device)

- **SQLite database** (one local file): your library metadata (titles, artists,
  albums, genres, years, durations, codecs, ReplayGain values), play counts and
  history, ratings, favorites, playlists and smart-playlist rules, the play
  queue, EQ presets, and app settings (including the resume bookmark, theme, and
  output device). Full schema: [`data-model.md`](data-model.md).
- **Album-art cache**: deduplicated cover images extracted from your files,
  stored as local files referenced by `art_cache`.
- **TLS identity** (only if you host sharing): a self-signed certificate + key
  generated on your device.
- **TOFU trust store** (`known_hosts`): for hosts you've connected to — their
  display name, color, and pinned certificate fingerprint.
- **Share config** (`shares`): which playlists you expose and how. PINs are
  stored **only as Argon2id hashes**, never in clear.
- **Approved-peer decisions** (`remembered_peers`) and a **transfer log**
  (who streamed/downloaded what from you), for the host's own dashboard.

Session bearer tokens for LAN auth live **in memory only** (as SHA-256 digests)
and are never written to disk.

## Everything transmitted (LAN only, opt-in)

Sharing is off until you enable it. When enabled:

- **mDNS advertisement** on `_peerbeat._tcp`: your host display name, a host id,
  and your certificate fingerprint — broadcast on the local network so peers can
  discover you. (You choose the display name; it need not identify you.)
- **To peers you authorize**: shareable playlist/library listings, track
  metadata + album art, and the **original audio bytes** you stream or allow to
  be downloaded — all over TLS.
- **From peers**: a PIN (if you set one), clock-sync pings, and optional track
  requests in party mode.

All of this stays on the LAN. PeerBeat makes no outbound internet connections.

## What is never collected or sent

- No user accounts, emails, or device identifiers tied to a service.
- No usage analytics, crash telemetry, or "phone-home" of any kind.
- No listening data leaves your device except the audio you deliberately share
  on your LAN.

## Your controls

- Sharing is opt-in per scope (Open / PIN / Approved-peers) with per-share
  stream-or-download permission.
- The host dashboard shows current streams/downloads and offers **one-tap revoke
  all** (which also drops live party sockets).
- The Network screen states plainly that everything is local-network only.
- Deleting the app's data directory removes the database, art cache, and TLS
  identity — there is nothing stored anywhere else.
