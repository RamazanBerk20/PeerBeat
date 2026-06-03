//! Per-host TLS identity: a self-signed cert + key, persisted so the
//! certificate fingerprint (the TOFU pin peers remember) is stable across
//! restarts. Uses the pure-Rust `ring` rustls provider (no aws-lc C build).

use sha2::{Digest, Sha256};
use std::fs;
use std::path::Path;
use std::sync::OnceLock;

/// A persisted host identity.
pub struct Identity {
    /// Stable random id used by peers to key the TOFU pin (survives IP changes).
    pub host_id: String,
    pub cert_pem: String,
    pub key_pem: String,
    /// Hex SHA-256 of the certificate DER — the value peers pin.
    pub fingerprint: String,
}

/// Install the rustls `ring` crypto provider exactly once (needed before
/// building any rustls `ServerConfig`). Idempotent.
pub fn ensure_provider() {
    static ONCE: OnceLock<()> = OnceLock::new();
    ONCE.get_or_init(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

/// Hex SHA-256 of `bytes`.
pub fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// Load the persisted identity from `dir`, creating + persisting a fresh one on
/// first run. Files: `host_cert.pem`, `host_key.pem`, `host_id`, `host_fp`.
pub fn load_or_create(dir: &Path) -> anyhow::Result<Identity> {
    let _ = fs::create_dir_all(dir);
    let cert_p = dir.join("host_cert.pem");
    let key_p = dir.join("host_key.pem");
    let id_p = dir.join("host_id");
    let fp_p = dir.join("host_fp");

    if let (Ok(cert_pem), Ok(key_pem), Ok(host_id), Ok(fp)) = (
        fs::read_to_string(&cert_p),
        fs::read_to_string(&key_p),
        fs::read_to_string(&id_p),
        fs::read_to_string(&fp_p),
    ) {
        if !cert_pem.is_empty()
            && !key_pem.is_empty()
            && !host_id.trim().is_empty()
            && !fp.trim().is_empty()
        {
            return Ok(Identity {
                host_id: host_id.trim().to_string(),
                cert_pem,
                key_pem,
                fingerprint: fp.trim().to_string(),
            });
        }
    }

    let ck = rcgen::generate_simple_self_signed(vec![
        "peerbeat.local".to_string(),
        "localhost".to_string(),
    ])?;
    let cert_pem = ck.cert.pem();
    let key_pem = ck.signing_key.serialize_pem();
    let fingerprint = sha256_hex(ck.cert.der().as_ref());
    let host_id = uuid::Uuid::new_v4().to_string();

    let _ = fs::write(&cert_p, &cert_pem);
    let _ = fs::write(&key_p, &key_pem);
    let _ = fs::write(&id_p, &host_id);
    let _ = fs::write(&fp_p, &fingerprint);

    Ok(Identity {
        host_id,
        cert_pem,
        key_pem,
        fingerprint,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_is_persistent_and_fingerprinted() {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("peerbeat_tls_{nanos}"));

        let a = load_or_create(&dir).unwrap();
        assert_eq!(a.fingerprint.len(), 64, "sha-256 hex is 64 chars");
        assert!(a.cert_pem.contains("BEGIN CERTIFICATE"));
        assert!(!a.host_id.is_empty());

        // second load returns the SAME identity (stable pin)
        let b = load_or_create(&dir).unwrap();
        assert_eq!(a.fingerprint, b.fingerprint);
        assert_eq!(a.host_id, b.host_id);

        std::fs::remove_dir_all(&dir).ok();
    }
}
