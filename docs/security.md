# PeerBeat — Security Model

PeerBeat's threat model is a **shared/untrusted local network** (e.g. café or
dorm Wi-Fi). Goals: confidentiality of streams on the wire, authenticity of the
host you connect to, and the host staying in control of who accesses what. There
is no internet attack surface because the app never connects to the internet.

## Transport: TLS 1.3, self-signed, pinned (TOFU)

- Each host generates an **EC self-signed certificate** (`rcgen`) once and
  persists it with the private key in the app-private dir (restrictive perms).
  There is no CA: LAN hosts have no public DNS, so Let's Encrypt-style trust is
  impossible — TOFU pinning is the right model.
- Peers **pin the SHA-256 of the certificate's SPKI** (the public key) on first
  connection. Pinning the SPKI (not the whole cert) lets a host rotate its cert
  without forcing peers to re-pin.
- The Rust core controls **both** the server and the streaming client, so the
  pinned trust decision is enforced in one place and the audio path uses the same
  pinned connection (no plaintext loopback-proxy hole).

### First-use & change handling
- **First sight**: the fingerprint is shown; the pin is stored when the user
  proceeds. If the peer arrived via **QR pairing**, the QR already carried the
  full fingerprint, so the connection is MITM-resistant from the very first byte.
- **Fingerprint mismatch later**: hard failure with a prominent warning. Never
  silently re-trust. This is the core defence against an on-path attacker.

## Authentication & authorization

Three host-selected modes gate issuance of a **session bearer token**:

- **Open** — token issued on connect.
- **PIN** — 4–6 digit PIN, verified once per session; stored only as a salted
  hash; rate-limited to resist brute force.
- **Approved** — host explicitly allows/denies each new peer (decision remembered
  per peer).

The token is **bound to the pinned certificate fingerprint** and **scoped to the
shares it was granted**. Audio Range requests carry the token; the server rejects
requests whose token lacks the relevant share grant. **Revoke** (one tap)
invalidates the token immediately and drops in-flight transfers.

## Per-share permissions

Each shared playlist is `stream` or `stream_download`. Download endpoints require
the `stream_download` grant; metadata/art previews are readable by any pinned
peer (so a peer can decide what to stream) but audio bytes are not.

## Abuse resistance

- Per-peer **concurrency + bandwidth caps**; a single transcode slot per peer.
- Request **rate-limiting** middleware on the host server.
- Every stream/download is recorded in `transfer_log`, surfaced live on the
  host's dashboard with per-peer disconnect + global revoke.

## Injection & input safety

- Smart-playlist rules compile to **parameterised SQL** with whitelisted columns
  and operators; user values are always bound, never interpolated.
- All file paths from peers (downloads) are sanitised; downloads are written only
  inside the user's library dir (no path traversal).
- Tag write-back validates field types and guards against the watch-folder
  re-scan loop.

## Key & secret handling (build/release)

- The Android signing keystore and the AUR deploy key are **never committed**.
  They exist only as local files and (for CI) base64-encoded GitHub Actions
  secrets, materialised ephemerally at build time. `.gitignore` blocks
  `*.keystore`, `*.jks`, `key.properties`, and cert/key files.

## Non-goals / honest limits

- TOFU cannot stop a MITM present at the *very first* connection unless QR pairing
  is used; the fingerprint is surfaced for optional out-of-band verbal check.
- PeerBeat is not a hardened multi-tenant server; it is a personal LAN share. The
  caps above mitigate accidental/abusive load, not a determined attacker who is
  already a trusted, pinned peer.
