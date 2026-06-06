//! M3U / M3U8 / PLS playlist import + export.
//!
//! Parsing yields file paths (relative entries resolved against the playlist's
//! directory); the caller matches them against the library by normalized path.
//! Emitting writes an extended-M3U or PLS with title + duration per entry.

use std::path::{Path, PathBuf};

/// One row for emitting a playlist file.
pub struct Entry {
    pub path: String,
    pub title: String,
    pub duration_secs: i64,
}

/// Whether `path` is a PLS file (by extension); everything else is M3U.
pub fn is_pls(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| e.eq_ignore_ascii_case("pls"))
        .unwrap_or(false)
}

fn resolve(raw: &str, base_dir: &Path) -> PathBuf {
    let raw = raw.strip_prefix("file://").unwrap_or(raw);
    let pb = PathBuf::from(raw);
    if pb.is_absolute() {
        pb
    } else {
        base_dir.join(pb)
    }
}

/// Parse an M3U/M3U8 playlist: each non-empty, non-`#` line is a path entry.
pub fn parse_m3u(content: &str, base_dir: &Path) -> Vec<PathBuf> {
    content
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| resolve(l, base_dir))
        .collect()
}

/// Parse a PLS playlist: `FileN=<path>` entries, returned ordered by `N`.
pub fn parse_pls(content: &str, base_dir: &Path) -> Vec<PathBuf> {
    let mut entries: Vec<(u32, PathBuf)> = Vec::new();
    for line in content.lines().map(str::trim) {
        let lower = line.to_ascii_lowercase();
        let Some(rest) = lower.strip_prefix("file") else {
            continue;
        };
        let Some(eq) = rest.find('=') else { continue };
        let Ok(n) = rest[..eq].parse::<u32>() else {
            continue;
        };
        // Take the value from the original (case-preserving) line. `split_once`
        // avoids an unwrap and is robust to any stray content before the '='.
        let val = line.split_once('=').map(|(_, v)| v.trim()).unwrap_or("");
        if !val.is_empty() {
            entries.push((n, resolve(val, base_dir)));
        }
    }
    entries.sort_by_key(|(n, _)| *n);
    entries.into_iter().map(|(_, p)| p).collect()
}

/// Emit an extended M3U (`#EXTM3U` + `#EXTINF` per entry).
pub fn to_m3u(entries: &[Entry]) -> String {
    let mut s = String::from("#EXTM3U\n");
    for e in entries {
        s.push_str(&format!(
            "#EXTINF:{},{}\n{}\n",
            e.duration_secs, e.title, e.path
        ));
    }
    s
}

/// Emit a PLS (v2).
pub fn to_pls(entries: &[Entry]) -> String {
    let mut s = String::from("[playlist]\n");
    for (i, e) in entries.iter().enumerate() {
        let n = i + 1;
        s.push_str(&format!("File{n}={}\n", e.path));
        s.push_str(&format!("Title{n}={}\n", e.title));
        s.push_str(&format!("Length{n}={}\n", e.duration_secs));
    }
    s.push_str(&format!("NumberOfEntries={}\nVersion=2\n", entries.len()));
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn m3u_roundtrip_and_relative_paths() {
        let base = Path::new("/music");
        let entries = vec![
            Entry {
                path: "/music/a.flac".into(),
                title: "A".into(),
                duration_secs: 180,
            },
            Entry {
                path: "/music/b.mp3".into(),
                title: "B".into(),
                duration_secs: 200,
            },
        ];
        let text = to_m3u(&entries);
        assert!(text.starts_with("#EXTM3U"));
        assert!(text.contains("#EXTINF:180,A"));
        let parsed = parse_m3u(&text, base);
        assert_eq!(
            parsed,
            vec![
                PathBuf::from("/music/a.flac"),
                PathBuf::from("/music/b.mp3")
            ]
        );

        // relative entries + comments resolve against base_dir
        let rel = "#EXTM3U\n# a comment\nsub/c.ogg\n\n/abs/d.wav\n";
        let parsed = parse_m3u(rel, base);
        assert_eq!(
            parsed,
            vec![
                PathBuf::from("/music/sub/c.ogg"),
                PathBuf::from("/abs/d.wav")
            ]
        );
    }

    #[test]
    fn pls_parse_orders_by_index_and_emits() {
        let base = Path::new("/m");
        let pls = "[playlist]\nFile2=/m/two.mp3\nTitle2=Two\nFile1=/m/one.flac\n\
                   Title1=One\nNumberOfEntries=2\nVersion=2\n";
        let parsed = parse_pls(pls, base);
        assert_eq!(
            parsed,
            vec![PathBuf::from("/m/one.flac"), PathBuf::from("/m/two.mp3")]
        );

        let out = to_pls(&[Entry {
            path: "/m/one.flac".into(),
            title: "One".into(),
            duration_secs: 123,
        }]);
        assert!(out.contains("File1=/m/one.flac"));
        assert!(out.contains("Length1=123"));
        assert!(out.contains("NumberOfEntries=1"));
    }

    #[test]
    fn file_uri_prefix_is_stripped() {
        let parsed = parse_m3u("file:///music/x.flac\n", Path::new("/base"));
        assert_eq!(parsed, vec![PathBuf::from("/music/x.flac")]);
    }
}
