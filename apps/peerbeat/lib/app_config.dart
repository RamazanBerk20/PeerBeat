/// Process-wide config set once in main(): the library DB path and this device's
/// display name (used when hosting on the LAN).
late String appDbPath;
late String appDisplayName;

/// On-disk path to the bundled app icon (extracted in main()), used as the
/// media-session artwork fallback for tracks without embedded cover art. Null
/// until extracted / if extraction fails.
String? appIconPath;
