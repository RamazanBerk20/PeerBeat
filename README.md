<div align="center">

<img src="assets/icon/PeerBeat.png" width="160" alt="PeerBeat icon" />

# PeerBeat

**A local-first music player with LAN peer-to-peer sharing.**
Windows · Linux · Android — no cloud, no accounts, nothing leaves your network.

[![CI](https://github.com/RamazanBerk20/PeerBeat/actions/workflows/ci.yml/badge.svg)](https://github.com/RamazanBerk20/PeerBeat/actions/workflows/ci.yml)
&nbsp;·&nbsp; License: GPL-3.0-or-later

</div>

---

PeerBeat plays your own music and lets you **share playlists with people on the
same Wi-Fi**: they discover your library automatically, stream tracks with full
controls, or download them — encrypted, and never touching the internet. Start a
**party** and everyone hears the same song in sync.

## Features

- **Playback** — gapless, configurable crossfade (0–12 s), pitch-preserving speed
  (0.5–2×), shuffle, repeat, resume-on-restart.
- **Library** — MP3/FLAC/WAV/AAC/OGG/M4A; read & edit tags; album art; browse by
  Songs/Albums/Artists/Genres/Years/Recently-Added; fast fuzzy search; watch-folders.
- **Playlists & queue** — drag-and-drop queue, Play-Next/Add-to-Queue, smart
  playlists from rules, auto-lists, M3U/PLS import-export.
- **LAN sharing** — mDNS discovery, TLS-encrypted streaming with cert pinning,
  Open/PIN/Approved access modes, per-playlist stream-or-download permissions,
  a host dashboard with one-tap revoke, and synchronized **party mode**.
- **Audio quality** — 10-band EQ + presets, ReplayGain, output-device selection,
  stereo widening.
- **Polish** — Now Playing with synced lyrics, persistent mini-player, dynamic
  theming from album art, light/dark, responsive desktop/phone/tablet layouts,
  WCAG 2.1 AA, OS media controls (MPRIS/SMTC/MediaSession), tray + media keys.

## Architecture

**Flutter UI** over a **shared Rust core** (`peerbeat_core`) via
`flutter_rust_bridge`. The Rust core owns the LAN protocol, the library/metadata
layer, the SQLite store, and the desktop audio engine; Android playback uses
ExoPlayer. See [`docs/architecture.md`](docs/architecture.md).

```
apps/peerbeat        Flutter app (android/ linux/ windows/ lib/)
packages/            pb_audio · pb_os · pb_design · peerbeat_bindings (FRB)
rust/peerbeat_core   db · library · audio · net · api (FRB boundary)
docs/                architecture · data-model · protocol · security · privacy
packaging/           windows(inno) · linux(appimage/deb/flatpak) · aur
```

## Build from source

Prerequisites: Flutter (stable), the Rust toolchain (`rustup`), and — for Android
— the Android SDK/NDK + `cargo-ndk`. JDK 17/21 for Android Gradle.

```bash
dart pub global activate melos
melos bootstrap
melos run frb-gen          # generate flutter_rust_bridge bindings
melos run rust-test        # cargo test the core
melos run test             # dart/flutter tests

flutter run -d linux       # or: -d windows, -d <android-device>
```

Reproducible Linux + Android builds run in `docker/Dockerfile.build`. Windows
installers are built by CI on a Windows runner (they cannot be cross-compiled from
Linux).

## Install

See the [Releases](https://github.com/RamazanBerk20/PeerBeat/releases) page:
Windows installer (`.exe`), Android `.apk`, Linux `AppImage`/`.deb`/Flatpak. Arch
users: `peerbeat` / `peerbeat-bin` on the AUR.

## Privacy

No accounts, no cloud, no telemetry, no internet connections. Everything is local;
LAN sharing is opt-in and encrypted. Full inventory in
[`docs/privacy.md`](docs/privacy.md).

## License

[GPL-3.0-or-later](LICENSE).
