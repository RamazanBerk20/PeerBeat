# PeerBeat — Privacy

**PeerBeat is offline-first and LAN-only.** It has no accounts, no cloud, no
telemetry, no analytics, no ads, and never requires an internet connection. The
app makes **no outbound internet connections** at all. The only data that ever
leaves your device goes **directly to a peer on your local network that you
explicitly shared with**.

This document lists *every* piece of data PeerBeat stores or transmits, and where.

## 1. Data stored on your device (local only)

| Data | Where | Notes |
|------|-------|-------|
| Track metadata (title, artist, album, genre, year, durations, codec, bitrate, ratings, play counts, last-played) | SQLite DB in app-private dir | Read from your files; editable |
| Play history (event log) | SQLite DB | Powers Recently/Most-Played + smart playlists |
| Playlists & smart-playlist rules | SQLite DB | |
| Album art | On-disk cache dir, deduped by image hash | Extracted from your files |
| EQ presets, settings, last playback position | SQLite DB / settings file | Resume-on-restart |
| Watch-folder paths | SQLite DB | Library roots you chose |
| **Known-host pins** (host id, display name, colour, certificate fingerprint) | SQLite DB | TOFU trust for LAN peers |
| **Remembered peers** (Approved-mode decisions) | SQLite DB | Allow/deny memory |
| **Your shares** (which playlists, permission, PIN hash) | SQLite DB | PIN stored only as a salted hash |
| **Transfer log** (who streamed/downloaded what, when) | SQLite DB | For your own safety dashboard; local |
| Your host identity (random id, display name, avatar colour) + self-signed TLS cert & private key | App-private dir, restrictive perms | Generated on first run; never leaves the device (only the public fingerprint is shared) |

Your **music files are never moved or copied** except when *you* download a track
from a peer (into your library) or *you* edit a tag (written back to that file).

## 2. Data transmitted — only over your LAN, only when you share

When you act as a **host** and mark playlists shareable, connected peers can
receive, over TLS on your local network:

| Data | When | To whom |
|------|------|---------|
| Host name, avatar colour, protocol version, **public** cert fingerprint | Advertised via mDNS + `GET /info` | Anyone on the LAN can see the advertisement |
| Shareable playlist names + track metadata + album art | On request | Pinned peers you allow (per your sharing mode) |
| Audio bytes (original file, or transcoded if needed) | On stream/download | Peers with a valid session token + permission |
| Connected-peer list (names/colours) | Only if you enable "peers can see each other" | Connected peers |
| Party-mode timing + control messages | In a party session you host | Party participants |

As a **peer**, you transmit to a host: your chosen display name, avatar colour, a
random peer id, and (if required) the host's session PIN. You receive the data
above into your own local library.

### What is *never* transmitted
- No data to any server on the internet — there is no server.
- No identifiers tied to your real identity (host/peer ids are random).
- No usage analytics or crash telemetry.
- Nothing leaves the LAN. The UI states this explicitly on the Network screen.

## 3. Security of what is transmitted

All LAN traffic is **TLS 1.3** with a per-host self-signed certificate, **pinned
on first use** (TOFU). On untrusted shared Wi-Fi this keeps your streams
encrypted and warns hard if a host's certificate ever changes (possible MITM).
PINs are transmitted over the established TLS channel and stored only as salted
hashes. See [`security.md`](security.md).

## 4. Permissions PeerBeat requests

| Platform | Permission | Why |
|----------|-----------|-----|
| Android | Read audio/media (`READ_MEDIA_AUDIO`) | Import your local music |
| Android | `POST_NOTIFICATIONS` | Playback notification |
| Android | `FOREGROUND_SERVICE` + `…_MEDIA_PLAYBACK` | Background playback |
| Android | `INTERNET` + `CHANGE_WIFI_MULTICAST_STATE` | **LAN sockets + mDNS only** (the `INTERNET` permission is required by Android for *local* TCP sockets; PeerBeat makes no internet calls) |
| All | Local network access | Discover/serve peers on the LAN |

## 5. Your controls

- Sharing is **off by default**; you choose exactly which playlists are shared and
  the mode (Open / PIN / Approved).
- The host dashboard shows every active stream/download and **revokes access with
  one tap**.
- You can clear known-host pins, remembered peers, and the transfer log at any
  time in Settings.
