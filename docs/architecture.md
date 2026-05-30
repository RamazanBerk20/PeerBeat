# PeerBeat — Architecture

PeerBeat is a **Flutter UI** over a **shared Rust core** (`peerbeat_core`), targeting
**Windows, Linux, and Android**. The Rust core owns the heavy, cross-platform
logic; Flutter owns the UI and the per-OS integration shell.

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Flutter app (Dart)                             │
│                                                                        │
│  UI: go_router shell · Now Playing · Library · Search · Network ·      │
│      Settings · persistent mini-player · Material 3 + dynamic colour   │
│  State: Riverpod                                                       │
│                                                                        │
│  pb_audio   AudioEngine ── RustDesktopEngine ─┐    ExoPlayerEngine ─┐  │
│  pb_os      OsMediaController (audio_service / smtc_windows / mpris) │  │
│             tray_manager · window_manager · session detect          │  │
│  pb_design  theme tokens · album-art palette · shared widgets       │  │
└───────────────────────────────│──────────────────────────────│───────┘
                                 │ flutter_rust_bridge (FFI)    │ platform
                                 ▼                              │ channels
┌──────────────────────────────────────────────────┐          ▼
│                 peerbeat_core (Rust)               │     ExoPlayer / Media3
│                                                    │     (Android playback,
│  api/      FRB boundary (thin)                     │      EQ effects, FGS)
│  db/       rusqlite + FTS5  (single source of      │
│            truth; reactive change-streams)         │
│  library/  scan · lofty tags · art cache · watch   │
│  audio/    symphonia → DSP → cpal  (DESKTOP only)  │
│  net/      mdns-sd · rustls host server · REST +   │
│            Range · WSS control · party sync · TOFU │
└────────────────────────────────────────────────────┘
```

## Why this split

- **One implementation of the hard parts.** The LAN protocol, library/metadata,
  the SQLite store, and the desktop DSP are written once in Rust and behave
  identically on every platform.
- **Native TLS pinning on both ends.** Because the Rust core is both the host
  server and the streaming client, a pinned self-signed stream is fed straight
  to the decoder — no localhost-proxy workaround (which an all-Dart design needs
  because ExoPlayer/libmpv ignore Dart's certificate callback).
- **No fragile platform deps.** `mdns-sd` removes the Avahi-daemon dependency a
  Dart mDNS plugin (`bonsoir`/`nsd`) would impose; the Rust cpal engine removes
  the libmpv runtime dependency on desktop.

## The one deliberate divergence: Android audio

Android background playback + `MediaSession` + audio-focus + lockscreen/notification
controls are table-stakes and are best served by **ExoPlayer/Media3** through
`just_audio` + `audio_service`. A custom Rust/cpal (AAudio) engine inside a
foreground service is feasible but high-risk for this exact surface, so:

| Platform | Playback engine | EQ / effects |
|----------|-----------------|--------------|
| Windows / Linux | Rust `audio/` (symphonia + cpal) | biquad EQ, ReplayGain, widener in Rust |
| Android | ExoPlayer (`just_audio`) | `DynamicsProcessing` (API 28+) / `Equalizer`, `LoudnessEnhancer` |

Both sit behind the Dart `AudioEngine` trait, so the UI, queue, OS controls, and
LAN streaming are engine-agnostic. (Full-Rust Android audio is a documented
future stretch.) **Networking, library, and the DB are uniform Rust everywhere.**

## Threading & data flow

- The Rust core runs a **Tokio runtime** (networking) and a dedicated **DB worker
  thread**; the desktop audio engine owns a real-time **cpal** callback thread fed
  by a lock-free ring buffer from a decode thread.
- Dart calls cross the FRB boundary as `async` futures; long-lived updates
  (playback position, scan progress, DB change notifications, incoming-transfer
  events) are delivered as **FRB streams** the Riverpod layer subscribes to.
- The DB is the source of truth. Writers (scanner) and readers (UI, LAN server)
  coordinate through SQLite WAL + an in-process change broadcaster that fans out
  to FRB streams.

## Module ownership

| Module | Responsibility | Milestone |
|--------|----------------|-----------|
| `api/` | FRB surface: validation + translation only | M0→ |
| `db/` | schema, migrations, FTS5 search, smart-query compiler | M1/M2 |
| `library/` | scan, tag r/w, art cache, watch-folders, M3U/PLS | M1/M2 |
| `audio/` | desktop transport, gapless/crossfade, DSP | M1/M2 |
| `net/` | discovery, TLS server, streaming, sharing, party | M2/M3 |
| `pb_audio` (Dart) | AudioEngine trait + both impls | M1 |
| `pb_os` (Dart) | OS media controls + desktop shell | M1/M3 |
| `pb_design` (Dart) | theme + dynamic colour + widgets + a11y | M1→ |

See [`data-model.md`](data-model.md), [`protocol.md`](protocol.md),
[`security.md`](security.md), and [`privacy.md`](privacy.md).
