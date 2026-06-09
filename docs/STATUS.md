# PeerBeat — Status

Honest done / partial / planned matrix against the original specification, as of
the **0.3.0 beta** push (the alpha→RC audit + fix pass). Legend: ✅ done ·
⚠️ partial · 🔭 planned · ❌ not yet.

## By spec area

### 0. Project setup — ✅
Docker reproducible build, git, Melos/pub workspace, FRB bridge, clean module
structure, app icon pipeline.

### 1. Core playback — ✅ (one caveat)
Play/pause/seek/prev/next, volume + mute, shuffle, repeat (off/all/one), gapless
(symphonia), configurable crossfade 0–12 s, resume-on-restart. Variable speed
0.5–2× is **pitch-preserving on Linux/macOS** (Signalsmith Stretch); ⚠️ on
**Windows** it currently falls back to a pitch-shifting resample.

### 2. Local library — ✅
Import MP3/FLAC/WAV/AAC/OGG/M4A; read + edit ID3/Vorbis/MP4 tags (with mojibake
recovery); embedded art + fallback; browse Songs/Albums/Artists/Genres/Years/
Recently-Added; FTS5 trigram fuzzy search; on-demand rescan + active watch-folders
with a per-folder watch toggle; duplicate detection (Find duplicates); 50k-track
scale covered by a test. ⚠️ Batch tag editing is still planned.

### 3. Playlists & queue — ✅
Full CRUD + duplicate + drag-reorder; queue with Play-Next / Add-to-Queue;
rule-based smart playlists (whitelisted, parameterized SQL); auto-lists
(Recently/Most/Never-Played, Favorites); M3U/PLS import-export.

### 4. LAN sharing — ✅ (polish ⚠️)
mDNS discovery (+ IPv6 fallback, + manual IP), host name/color, Open/PIN/
Approved-peers modes (remembered), per-playlist stream vs stream+download,
streaming (HTTP Range) + downloads, transfer log + one-tap revoke, TLS + TOFU
pinning, explicit LAN-only UI, **party mode** with corrected Cristian clock-sync
+ auto-reconnect. ⚠️ Remaining polish: remote volume control, metadata/art
preview *before* streaming, and a host toggle for peer-visibility.

### 5. Audio quality — ✅ desktop / ❌ Android
10-band EQ + presets, ReplayGain, output-device selection, stereo widening — all
in the desktop Rust engine. ❌ On Android the engine is a stub; wiring
`just_audio`'s `AndroidEqualizer`/`LoudnessEnhancer` is planned for RC.

### 6. UI / UX — ✅ (full WCAG pass ⚠️)
Now Playing (large art, scrubber, auto-scrolling synced `.lrc`/embedded lyrics,
real-time spectrum **visualizer**, up-next), persistent mini-player, light/dark +
album-art dynamic theming **plus a System/Light/Dark selector and accent picker**,
responsive desktop/phone/tablet layouts, desktop keyboard shortcuts.
Accessibility: tap
targets ≥48 dp, non-colour state cues, screen-reader labels and an efficient
synced-lyrics view are done; ⚠️ a full WCAG 2.1 AA pass (keyboard focus
traversal everywhere, contrast audit) is in progress.

### 7. OS integration — ✅ core / ❌ extras
MPRIS (Linux, spec-correct Volume + clean name handling), SMTC (Windows),
Android lockscreen/notification/background, system tray + close-to-tray, Wayland
fallback to system notifications. ❌ Not yet: the custom sliding notification
popup + tray-anchored mini-player (X11/Windows), and Android Auto. ⚠️ Headset/BT
controls rely on the OS media session.

### 8. Non-functional — ✅
Offline-first, SQLite data model documented, 50k-track load covered by a test.
Scrub-latency and LAN first-audio targets are plausible but not yet benchmarked
(RC).

### 9. Publish — ✅ (Flatpak ❌, version sync pending)
Public GitHub repo + Releases workflow building Windows `.exe`, Android
`.apk`/`.aab`, Linux AppImage/`.deb`; AUR `peerbeat` + `peerbeat-bin`.
❌ Flatpak is specified but not yet built. Version strings across
Cargo/Inno/metainfo/AUR are being synced to the release version.

## Known-not-bugs (audit false positives, intentionally unchanged)

The audit's adversarial verification refuted several "races": the SQLite store is
serialized behind a process-wide mutex, and Dart's single-threaded event loop
makes the pause-vs-advance microtask ordering safe. These are documented here so
they aren't "re-fixed" later.

## Tracked for the RC hardening pass

- Pitch-preserving speed on Windows (or documented fallback).
- Android EQ/ReplayGain via `just_audio`.
- Custom sliding notification + tray mini-player; Android Auto.
- Flatpak packaging; full version sync; AUR bump at release.
- Per-peer streaming byte-rate limit.
- Full WCAG 2.1 AA verification + scrub/first-audio benchmarks.
- 100× feature themes — shipped: spectrum visualizer + lyrics auto-scroll,
  smarter library (per-folder watch toggle + duplicate detection),
  personalization (theme selector, accent picker, more shortcuts). Remaining:
  lyrics tap-to-seek/editor, batch tag editing, and party/social polish
  (reconnect UI, chat/reactions, transfer dashboard).
