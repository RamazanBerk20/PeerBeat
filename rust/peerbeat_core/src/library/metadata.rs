//! Tag + audio-property reading via `lofty` (MP3/FLAC/WAV/AAC/OGG/M4A).

use crate::db::tracks::NewTrack;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::tag::{Accessor, ItemKey};
use std::path::Path;

/// Audio file extensions PeerBeat imports.
pub const AUDIO_EXTS: &[&str] = &["mp3", "flac", "wav", "aac", "ogg", "oga", "m4a"];

/// Whether `path` looks like an importable audio file (by extension).
pub fn is_audio(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| AUDIO_EXTS.contains(&e.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

fn stem(path: &Path) -> String {
    path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown")
        .to_string()
}

/// Normalised path key: forward slashes everywhere; case-folded on Windows.
pub fn normalize_path(path: &Path) -> String {
    let s = path.to_string_lossy().replace('\\', "/");
    if cfg!(windows) {
        s.to_lowercase()
    } else {
        s
    }
}

fn codec_from_ext(path: &Path) -> String {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default()
}

/// Split a multi-value tag string on the common `;`/null separators. Conservative
/// (does not split on `/` so "AC/DC" survives). Empty -> empty vec.
fn split_multi(s: &str) -> Vec<String> {
    s.split(['\u{0}', ';'])
        .map(|p| p.trim())
        .filter(|p| !p.is_empty())
        .map(|p| p.to_string())
        .collect()
}

/// Parse a ReplayGain value like "-6.50 dB" into decibels.
fn parse_db(s: &str) -> Option<f64> {
    s.trim()
        .trim_end_matches(|c: char| c.is_alphabetic() || c.is_whitespace())
        .trim()
        .parse::<f64>()
        .ok()
}

/// Read tags + audio properties into a [`NewTrack`]. Falls back to the filename
/// for the title when untagged.
pub fn read_tags(
    path: &Path,
    file_size: i64,
    mtime_ns: i64,
    added_at: i64,
) -> anyhow::Result<NewTrack> {
    let tagged = lofty::read_from_path(path)?;
    let props = tagged.properties();

    let mut nt = NewTrack {
        path: path.to_string_lossy().to_string(),
        normalized_path: normalize_path(path),
        duration_ms: props.duration().as_millis() as i64,
        bitrate: props.audio_bitrate().map(|b| b as i64),
        sample_rate: props.sample_rate().map(|s| s as i64),
        channels: props.channels().map(|c| c as i64),
        codec: codec_from_ext(path),
        file_size,
        mtime_ns,
        added_at,
        title: stem(path),
        ..Default::default()
    };

    if let Some(tag) = tagged.primary_tag().or_else(|| tagged.first_tag()) {
        if let Some(t) = tag.title() {
            if !t.trim().is_empty() {
                nt.title = t.to_string();
            }
        }
        if let Some(a) = tag.artist() {
            nt.artists = split_multi(&a);
        }
        nt.album = tag.album().map(|a| a.to_string()).filter(|s| !s.is_empty());
        nt.album_artist = tag
            .get_string(ItemKey::AlbumArtist)
            .map(|s| s.to_string())
            .filter(|s| !s.is_empty());
        if let Some(g) = tag.genre() {
            nt.genres = split_multi(&g);
        }
        nt.year = tag.get_string(ItemKey::Year).and_then(|s| {
            let s = s.trim();
            s.parse::<i64>()
                .ok()
                .or_else(|| s.get(0..4).and_then(|y| y.parse().ok()))
        });
        nt.track_no = tag.track().map(|t| t as i64);
        nt.disc_no = tag.disk().map(|d| d as i64);
        nt.replaygain_track_db = tag
            .get_string(ItemKey::ReplayGainTrackGain)
            .and_then(parse_db);
        nt.replaygain_album_db = tag
            .get_string(ItemKey::ReplayGainAlbumGain)
            .and_then(parse_db);
        nt.has_lyrics = tag.get_string(ItemKey::Lyrics).is_some();
    }

    Ok(nt)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn extension_filter() {
        assert!(is_audio(Path::new("/m/x.FLAC")));
        assert!(is_audio(Path::new("/m/x.mp3")));
        assert!(!is_audio(Path::new("/m/cover.jpg")));
        assert!(!is_audio(Path::new("/m/notes.txt")));
    }

    #[test]
    fn multi_value_split_keeps_acdc() {
        assert_eq!(split_multi("AC/DC"), vec!["AC/DC"]);
        assert_eq!(split_multi("A; B;C"), vec!["A", "B", "C"]);
        assert!(split_multi("  ").is_empty());
    }

    #[test]
    fn replaygain_parse() {
        assert_eq!(parse_db("-6.50 dB"), Some(-6.5));
        assert_eq!(parse_db("3.2"), Some(3.2));
        assert_eq!(parse_db("n/a"), None);
    }
}
