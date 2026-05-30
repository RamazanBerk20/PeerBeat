//! Core lifecycle / introspection exposed to Dart.

/// Semantic version of `peerbeat_core` (matches the crate version).
pub fn core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// A short banner the Dart side can show in About/Settings to confirm the native
/// core loaded and bridged successfully.
pub fn core_banner() -> String {
    format!("PeerBeat core v{} — LAN-only, offline-first", core_version())
}

/// Initialise process-wide state for the core: logging and the default crypto
/// provider for rustls. Safe to call multiple times.
pub fn init_core() {
    // Subsystems (tokio runtime, rustls provider, tracing subscriber) are
    // initialised here as they are introduced. Kept idempotent on purpose.
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_non_empty_semver() {
        let v = core_version();
        assert!(!v.is_empty());
        assert_eq!(v.split('.').count(), 3, "expected MAJOR.MINOR.PATCH, got {v}");
    }

    #[test]
    fn banner_mentions_lan_only() {
        assert!(core_banner().contains("LAN-only"));
    }
}
