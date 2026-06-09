# Changelog

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
