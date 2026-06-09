# PeerBeat — Architecture

PeerBeat is a local-first music player with LAN peer-to-peer sharing for
**Windows, Linux, and Android**. It is one codebase: a **Flutter** UI over a
shared **Rust core** (`peerbeat_core`) bridged by
[`flutter_rust_bridge`](https://cjycode.com/flutter_rust_bridge/) (FRB).

## Why this stack

- **One UI, three targets.** Flutter renders the same widget tree on Windows,
  Linux (GTK), and Android, with responsive layouts for phone/tablet/desktop.
- **One core, native speed.** The library scanner, metadata/tag layer, SQLite
  store, LAN protocol, and the desktop audio engine live in Rust — fast,
  memory-safe, and shared verbatim across platforms.
- **A typed bridge.** FRB generates the Dart⇄Rust binding (`lib/src/rust/**`
  from `rust/peerbeat_core/src/api/**`), so the UI calls the core as ordinary
  Dart with no hand-written FFI.

## Repository layout

```
apps/peerbeat/          Flutter app
  lib/
    playback/player.dart     PlayerController: queue, shuffle/repeat, resume
    audio/audio_engine.dart  AudioEngine abstraction (desktop Rust / Android just_audio)
    net/{party,tofu}.dart    party-mode client + TOFU TLS HttpClient
    os/                      MPRIS (Linux) · SMTC (Windows) · tray / close-to-tray
    ui/                      screens: library, now playing, network, settings, …
    src/rust/                FRB-generated bindings (do not edit by hand)
  android/ linux/ windows/   per-platform runners + manifests
packages/pb_design/     (placeholder design package)
rust/peerbeat_core/     the shared core
  src/api/              FRB boundary (audio, library, network, system, simple)
  src/audio/            desktop engine: rodio sink, EQ, time-stretch, widening
  src/db/               SQLite schema + DAOs
  src/library/          scan, metadata (lofty), album art, playlist I/O
  src/net/              discovery (mdns-sd), TLS (rustls+rcgen), server (axum), party
docs/                   this documentation set
packaging/              windows (Inno) · linux (AppImage/deb) · aur
docker/Dockerfile.build reproducible Linux + Android build image
```

## Layers

1. **UI (Dart/Flutter).** Material 3. `PlayerController` (a `ChangeNotifier`)
   owns playback/queue state; a separate high-frequency `positionNotifier`
   drives the scrubber so position ticks never rebuild the whole tree.
2. **Audio.** `AudioEngine` is an interface. On desktop it forwards to the Rust
   engine (`api/audio.rs` → `audio/engine.rs`, a rodio sink with a 10-band EQ,
   Signalsmith time-stretch, ReplayGain, and stereo widening). On Android it is
   backed by `just_audio` / `just_audio_background` (which also provides the
   MediaSession).
3. **Core API (`src/api`).** Every function returns `Result<T, String>` (or is
   infallible) so errors cross the bridge cleanly — no panics on reachable
   paths.
4. **Domain (`src/db`, `src/library`, `src/net`).** Pure Rust: the data model,
   scanning, and the LAN protocol.

## Concurrency model

- The SQLite store is guarded by a process-wide `Mutex` (`with_db` in
  `api/library.rs`); the scanner, the watch-folder loop, and UI-driven queries
  all serialize through it, so the DAOs need no internal locking.
- The LAN host runs its own **Tokio** runtime on a dedicated thread
  (`api/network.rs`); HTTP handlers do blocking DB work on
  `spawn_blocking`. Shared host state (sessions, approvals, the party hub) is
  `Arc<Mutex<…>>`; no lock is held across an `.await`.
- The desktop audio engine runs on its own thread and is driven by a command
  channel; the UI never blocks on audio work.

## OS integration

- **Linux:** MPRIS over D-Bus (media keys, lockscreen, now-playing) + a
  system-tray icon/menu with close-to-tray. On **Wayland** the app cannot place
  windows, so the custom tray-anchored popup is skipped in favour of the
  compositor's tray and the OS's own notifications.
- **Windows:** System Media Transport Controls (SMTC) + tray + close-to-tray.
- **Android:** `just_audio_background` provides the foreground media service,
  lockscreen/notification controls, and background playback.

See [`data-model.md`](data-model.md), [`protocol.md`](protocol.md),
[`security.md`](security.md), [`privacy.md`](privacy.md), and the live
done/partial/planned matrix in [`STATUS.md`](STATUS.md).
