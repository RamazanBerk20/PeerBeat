# Changelog

## 0.3.0 — beta (audit + hardening)

An audit-driven correctness, security, and accessibility pass on the way to a
release candidate, plus a documentation rebuild and the first personalization
features.

### Features
- **Personalization**: a Theme selector (System / Light / Dark — previously
  dark-only) and an accent-colour picker (8 presets + the default) under
  Settings → Appearance; the chosen accent is the fallback when dynamic
  album-art theming finds no strong colour. Extra desktop shortcuts: `n`/`p`
  (next/previous track) and `[`/`]` (speed −/+).
- **Lyrics**: the synced `.lrc` view now auto-scrolls to keep the current line
  centred.
- **Library**: per-folder watch toggle in Library → Folders — mute auto-import
  for a folder while still being able to scan it on demand (the `is_watched`
  flag is now honoured by the watcher).
- **Library**: duplicate detection — Library → Folders → "Find duplicates"
  groups byte-identical tracks (shared content hash) and removes the extras
  from the library (files on disk are never deleted).

### Fixes (correctness & security)
- Playback speed is clamped to the engine-safe 0.5–2× in the UI (no more silent
  re-clamping); the engine carries fractional milliseconds across speed changes.
- LAN: session tokens are stored as SHA-256 digests (not plaintext) in memory;
  download `Content-Disposition` filenames strip control characters; the party
  broadcast buffer was enlarged and a lagging peer is resent the latest snapshot
  instead of silently desyncing.
- Party sync: the Cristian clock-sync offset now captures one receive timestamp
  (fixing the error that broke the ~100 ms target), peers auto-reconnect with
  backoff, and a joining/following peer loads already seeked to the target
  position (no audible play-from-zero).
- Discovery: IPv6 fallback; manual connect reuses a discovered host's identity
  to avoid a duplicate TOFU trust anchor.
- Linux MPRIS reports Volume independently of mute (spec compliance) and tears
  down a stolen media-player name cleanly; the tray temp icon is cleaned up.
- Cross-cutting: previously-swallowed database errors (party request titles,
  remembered-peer persistence, watch-folder rescans) are now logged/propagated.

### Accessibility
- Mini-player transport tap targets are back to ≥48 dp; shuffle/repeat/speed
  expose non-colour state cues; the now-playing track exposes a screen-reader
  label; the synced-lyrics view rebuilds per active line, not per position tick.

### Docs
- Rebuilt `docs/` from the current code: `architecture`, `data-model`,
  `protocol`, `security`, `privacy`, and an honest `STATUS` matrix. README and
  module docs de-staled (shipped features were still listed as "roadmap").

### Tests
- Added regression coverage: speed clamp, party clock-sync math, `playQueue`
  start-position, and PIN hashing + legacy-hash rejection.

## 0.2.0 — beta (alpha → RC push)

A large stabilization, security, and UX release taking PeerBeat from alpha
toward a release candidate.

### Security & stabilization
- LAN auth hardening: session tokens now carry a 12 h TTL (rejected + swept on
  expiry); the party WebSocket is token-gated and re-validated live (closes a
  hole where any LAN device could read the host's now-playing state); per-IP
  rate-limit on `/v1/auth/session` (429 + `Retry-After`) against PIN
  brute-force; share PINs are stored Argon2id-hashed and validated as 4–6
  digits (existing PINs require a one-time re-entry after upgrade).
- Robustness: collision-safe LAN stream cache key + size cap; PLS parser no
  longer panics on malformed lines; operational failures routed through a debug
  log sink instead of being swallowed; removed dead stub packages.

### LAN sharing
- **Approved-peers** share mode (previously a stub): a peer connecting to an
  "approved" share waits while the host gets an Allow / Always allow / Deny
  prompt on the Network screen; decisions can be remembered.
- **Connect by IP** fallback when mDNS discovery doesn't surface a host.
- **Party requests**: while joined to a host's party, long-press a track to ask
  the host to play it; the host sees and actions requests.
- Discovered hosts and connected peers get distinct color avatars.

### Platform / OS integration
- **Android**: real lockscreen + notification controls and background playback
  (foreground media service via `just_audio_background`, with track metadata +
  artwork).
- **Windows**: System Media Transport Controls (media widget + hardware keys).
- Linux MPRIS unchanged.

### Playback & library
- Gapless playback for compressed formats (encoder delay/padding trimmed).
- Songs list is now infinite-scroll/paginated — no more 5 000-track cap; a 50k
  library's first page loads well under budget.

### UI / UX ("Expressive" redesign)
- New design system: bold display type, rounded surfaces, tonal navigation.
- **Dynamic theming**: the app tints itself from the current track's album art
  (computed only on track change; reintroduced safely after the earlier crash).
  Toggle in Settings → Appearance.
- Now Playing: album-art-forward gradient backdrop, a reorderable queue sheet
  (drag / remove / jump), and a sleep timer (fade-out then pause).
- Easier navigation: long-press a track for its actions menu (mobile-friendly);
  drag a folder onto the library (desktop) to add + scan it.
- A real graphic equalizer (vertical band sliders); empty-library onboarding;
  accessibility labels on transport controls and the scrubber.

### Notes
- Release artifacts (Windows installer, Android APK/AAB, Linux AppImage/deb, AUR
  `peerbeat`/`peerbeat-bin`) are produced by the tagged CI release workflow.
- On-device verification of Android background/lockscreen, Windows SMTC, and
  two-device party sync is recommended before cutting the tag.
