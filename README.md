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

What works today:

- **Playback** — play/pause/seek/prev/next, shuffle, repeat (off/all/one), volume +
  mute, variable speed, resume-on-restart.
- **Library** — MP3/FLAC/WAV/AAC/OGG/M4A; read & edit tags; album art with fallback;
  browse by Songs/Albums/Artists/Genres/Years/Recently-Added; fast FTS5 fuzzy search;
  add folders + on-demand rescan.
- **Playlists & queue** — full playlist CRUD + duplicate + drag-and-drop reorder,
  Play-Next/Add-to-Queue, rule-based smart playlists, M3U/PLS import-export.
- **LAN sharing** — mDNS discovery (+ manual IP), per-host self-signed **TLS with
  TOFU certificate pinning**, and HTTP-Range streaming of a host's library; the UI
  makes it explicit that nothing leaves the local network.
- **Audio quality** — 10-band graphic EQ + built-in & custom presets, ReplayGain
  normalization, output-device selection, stereo widening.
- **Now Playing & UI** — large artwork, scrubber, up-next, persistent mini-player,
  light/dark Material 3, responsive desktop/phone/tablet layouts.
- **OS integration** — MPRIS media controls + media keys on Linux; Android playback
  via ExoPlayer (lockscreen / notification / background).

## Roadmap

Targeted next — see [`docs/STATUS.md`](docs/STATUS.md) for the full done/partial/planned matrix:

- **Audio engine** — gapless, configurable crossfade (0–12 s), and *pitch-preserving*
  speed (the current desktop engine shifts pitch with speed).
- **LAN sharing** — mark playlists shareable, Open/PIN/Approved access modes,
  per-playlist stream-or-download permissions, track/playlist **downloads**, a host
  dashboard of active transfers with one-tap revoke, and synchronized **party mode**
  over a WebSocket control channel.
- **Library/UX** — active watch-folders, auto-lists (Recently/Most/Never-Played,
  Favorites), a synced **lyrics** panel (`.lrc` / embedded), dynamic theming from
  album art, keyboard shortcuts + gestures, and a full WCAG 2.1 AA pass.
- **OS integration** — Windows SMTC, a tray mini-player + custom sliding notification
  (with a Wayland fallback to system notifications), close-to-tray, and Android Auto.

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
