# PeerBeat — Implementation Status

Honest snapshot of what is built today vs. on the roadmap. `✅ done` ·
`🟡 partial` · `⛔ planned`. The README and module docs link here; the long-form
build-out is tracked in the project plan.

## 1. Core playback
| Feature | Status | Notes |
|---|---|---|
| Play/pause/prev/next/seek, volume, mute | ✅ | `playback/player.dart`, `audio/engine.rs` |
| Shuffle, repeat (off/all/one) | ✅ | |
| Resume from last position | ✅ | persisted track id + position |
| Variable speed (pitch-preserving) | ✅ | Signalsmith time-stretch (`audio/timestretch.rs`); UI 0.5–2×; bypassed bit-exact at 1.0× |
| Gapless playback | ⛔ | rodio interim; fresh sink per track |
| Configurable crossfade (0–12 s) | ✅ | dual-sink equal-time fade, opt-in (`audio.crossfade`; default 0 = unchanged) |

## 2. Library
| Feature | Status | Notes |
|---|---|---|
| Import MP3/FLAC/WAV/AAC/OGG/M4A | ✅ | `library/scan.rs`, lofty |
| Read & edit tags | ✅ | `library/metadata.rs` write-back |
| Embedded art + fallback | ✅ | `library/art.rs`, cached per album |
| Browse Songs/Albums/Artists/Genres/Years/Recent | ✅ | `db/browse.rs` |
| Fast fuzzy search | ✅ | FTS5 trigram + bm25 |
| Manual rescan / prune | ✅ | `library_rescan_all` |
| Active watch-folders | ✅ | `notify` watcher: debounced incremental rescan/prune on file changes (UI refreshes on next navigation) |

## 3. Playlists & queue
| Feature | Status | Notes |
|---|---|---|
| Create/rename/reorder/duplicate/delete | ✅ | `db/playlists.rs` |
| Drag-drop queue, Play-Next, Add-to-Queue | ✅ | |
| Smart playlists (rules → parameterized SQL) | ✅ | `db/smart.rs` |
| M3U/PLS import-export | ✅ | `library/playlist_io.rs` |
| Auto-lists (Recently/Most/Never-Played, Favorites) | ✅ | play tracking + favorites DAO/API + browse tiles + heart toggle |

## 4. LAN sharing (the differentiator)
| Feature | Status | Notes |
|---|---|---|
| mDNS discovery + manual IP | ✅ | `net/discovery.rs` |
| Per-host TLS + TOFU cert pinning | ✅ | `net/tls.rs`, `net/tofu.dart` |
| HTTP-Range streaming of host library | ✅ | `net/server.rs` `/v1/stream/{id}` |
| LAN-only made explicit in UI | ✅ | network screen banner |
| Display name in discovery | ✅ | (avatar/color advertised: ⛔) |
| Mark playlists/library shareable | ✅ | `db/shares.rs` + Sharing screen |
| Open / PIN access modes | ✅ | token-scoped server auth (`net/server.rs`) |
| Approved-peer access mode | ⛔ | pends the WebSocket control channel |
| Per-playlist stream-vs-download permissions | ✅ | enforced server-side per token scope |
| List shared playlists / pick a scope | ✅ | `/v1/shares` + `/v1/playlists` + peer picker |
| Pre-stream metadata / art preview | 🟡 | `/v1/tracks/{id}/meta` + `/art` endpoints; dedicated preview UI pending |
| Download tracks (tags + art) | ✅ | per-track download + import into a local folder (playlist ZIP pending) |
| See connected peers (peer↔peer) | ⛔ | needs the WebSocket control channel |
| Host activity dashboard + revoke | ✅ | active peers + recent stream/download log; per-peer **and** revoke-all |
| WebSocket control channel | ✅ | host `/v1/party` WS (state broadcast + clock-sync pong) + Dart peer client |
| Party mode (sync ≤100 ms, host control) | 🟡 | full host broadcast + peer clock-sync/follow built — **experimental**, needs 2-device verification |
| Party: peer track requests | ⛔ | optional per spec; not built |

> Note: the desktop "stream" path currently downloads the TOFU-verified stream to a
> temp cache file and plays that; true incremental Range streaming straight to the
> decoder is a roadmap item.

## 5. Audio quality
| Feature | Status | Notes |
|---|---|---|
| 10-band graphic EQ + built-in & custom presets | ✅ | `audio/eq.rs`, `db/eq_presets.rs` |
| ReplayGain / loudness normalization | ✅ | `audio/replay_gain.dart` |
| Output-device selection (desktop) | ✅ | cpal enumeration |
| Stereo widening | ✅ | `audio/widen.rs` |

## 6. UI
| Feature | Status | Notes |
|---|---|---|
| Now Playing (art, scrubber, up-next) | ✅ | `ui/now_playing.dart` |
| Persistent mini-player | ✅ | |
| Light/dark Material 3 | ✅ | |
| Responsive desktop/phone/tablet | ✅ | |
| Lyrics panel (`.lrc` / embedded) | ✅ | sidecar `.lrc` + embedded tag; synced highlighting in Now Playing |
| Dynamic theming from album art | ⛔ | reverted — the async per-track root-`MaterialApp` rebuild reparented overlay render objects mid-transition (red-screen crash); needs a non-root-rebuild approach (e.g. theme a region below the Navigator) |
| Keyboard shortcuts | ✅ | global play/pause, seek, prev/next, volume, mute, shuffle, repeat |
| Gestures (mobile) | ⛔ | |
| WCAG 2.1 AA (screen-reader/keyboard) | 🟡 | tooltips + keyboard nav + slider value announcements + decorative-art exclusion; full audit still pending |

## 7. OS integration
| Feature | Status | Notes |
|---|---|---|
| MPRIS media controls + media keys (Linux) | ✅ | `os/os_media_controller.dart` |
| Android lockscreen/notification/background | 🟡 | just_audio/ExoPlayer baseline |
| Windows SMTC | ⛔ | |
| System tray menu + close-to-tray (Win/Linux) | ✅ | tray icon + Play/Pause/Next/Prev/Show/Quit; close hides to tray (armed only if the tray initializes, so a tray-less compositor isn't stranded) |
| Custom sliding notification + positioned mini-player popup | ⛔ | X11-only by nature; intentionally omitted on Wayland (the compositor controls window position) — tray menu + system notifications used instead |
| Bluetooth / wired headset controls | 🟡 | via platform defaults (MPRIS / ExoPlayer) |
| Android Auto | ⛔ | |

## 9. Publish
| Item | Status | Notes |
|---|---|---|
| Public GitHub repo | ✅ | |
| Release CI: Windows `.exe`, Android apk+aab, Linux AppImage+deb | ✅ | `.github/workflows/release.yml` |
| AUR `peerbeat` / `peerbeat-bin` | ✅ | `packaging/aur/` |
