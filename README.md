<div align="center">

<img src="assets/icon/PeerBeat.png" width="160" alt="PeerBeat icon" />

# PeerBeat

**A local-first music player with LAN peer-to-peer sharing.**
Windows · Linux · Android — no cloud, no accounts, nothing leaves your network.

[![CI](https://github.com/RamazanBerk20/PeerBeat/actions/workflows/ci.yml/badge.svg)](https://github.com/RamazanBerk20/PeerBeat/actions/workflows/ci.yml)
&nbsp;·&nbsp; License: GPL-3.0-or-later
&nbsp;·&nbsp; [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-db61a2?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/RamazanBerk20)

</div>

---

PeerBeat plays your own music and lets you **share playlists with people on the
same Wi-Fi**: they discover your library automatically, stream tracks with full
controls, or download them — encrypted, and never touching the internet. Start a
**party** and everyone hears the same song in sync.

## Features

What works today:

- **Playback** — play/pause/seek/prev/next, shuffle, repeat (off/all/one), volume +
  mute, gapless, configurable crossfade (0–12 s), variable speed (0.5–2×,
  pitch-preserving on Linux/macOS), resume-on-restart.
- **Library** — MP3/FLAC/WAV/AAC/OGG/M4A; read & edit tags; album art with fallback;
  browse by Songs/Albums/Artists/Genres/Years/Recently-Added; fast FTS5 fuzzy search;
  add folders + watch + on-demand rescan.
- **Playlists & queue** — full playlist CRUD + duplicate + drag-and-drop reorder,
  Play-Next/Add-to-Queue, rule-based smart playlists, auto-lists
  (Recently/Most/Never-Played, Favorites), M3U/PLS import-export.
- **LAN sharing** — mDNS discovery (+ manual IP), per-host self-signed **TLS with
  TOFU certificate pinning**, Open/PIN/Approved-peers access modes, per-playlist
  stream-or-download permissions, HTTP-Range streaming **and downloads**, a host
  dashboard of active transfers with one-tap revoke, and synchronized **party mode**
  over a WebSocket clock-sync channel. The UI makes it explicit that nothing leaves
  the local network.
- **Audio quality** — 10-band graphic EQ + built-in & custom presets, ReplayGain
  normalization, output-device selection, stereo widening (desktop engine).
- **Now Playing & UI** — large artwork, scrubber, up-next, synced `.lrc`/embedded
  **lyrics**, persistent mini-player, light/dark Material 3 with **album-art dynamic
  theming**, responsive desktop/phone/tablet layouts, desktop keyboard shortcuts.
- **OS integration** — MPRIS (Linux) + SMTC (Windows) media controls & keys; system
  tray + close-to-tray (Wayland falls back to system notifications); Android
  lockscreen / notification / background playback.
- **Languages** — the UI is localized into 10 languages (English, Turkish, Spanish,
  French, German, Russian, Arabic — with RTL —, Japanese, Chinese, Korean); pick one
  in Settings → Language or follow the system locale.
- **Auto-update** — Windows and Android builds (side-loaded from GitHub Releases)
  check for new versions on launch and from Settings, then download and hand off to
  the OS installer; you always confirm the install. Linux updates are left to your
  package manager (AUR / `.deb` / AppImage).

## Roadmap

Targeted next — see [`docs/STATUS.md`](docs/STATUS.md) for the full done/partial/planned matrix:

- **Audio** — pitch-preserving speed on Windows; EQ/ReplayGain on Android.
- **LAN/UX** — remote volume + metadata/art preview before streaming; per-folder
  watch toggle; a full WCAG 2.1 AA pass (keyboard focus traversal, contrast).
- **OS integration** — a tray-anchored mini-player + custom sliding notification on
  X11/Windows, and Android Auto.
- **Packaging** — Flatpak alongside AppImage/`.deb`.
- **100× features** — synced-lyrics polish + audio visualizer, a smarter library
  (live watch, batch tag editing, duplicate detection), party/social polish, and
  personalization (theme presets, layouts, full shortcuts/gestures).

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

## Support

PeerBeat is free and open source, built in the open. If it's useful to you,
consider **[sponsoring on GitHub](https://github.com/sponsors/RamazanBerk20)** —
it funds the time that goes into new features, platform testing, and releases.
Every bit helps, and starring the repo is appreciated too. 💜

## License

[GPL-3.0-or-later](LICENSE).
