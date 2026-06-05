//! Tag + audio-property reading via `lofty` (MP3/FLAC/WAV/AAC/OGG/M4A).

use crate::db::tracks::NewTrack;
use lofty::config::WriteOptions;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::tag::{Accessor, ItemKey, Tag, TagExt};
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

/// Lyrics for a track: a sidecar `.lrc` next to the file (preferred — it may be
/// time-synced) or the embedded lyrics tag. `None` when neither exists.
pub fn read_lyrics(path: &Path) -> Option<String> {
    let lrc = path.with_extension("lrc");
    if let Ok(text) = std::fs::read_to_string(&lrc) {
        if !text.trim().is_empty() {
            return Some(text);
        }
    }
    let tagged = lofty::read_from_path(path).ok()?;
    let tag = tagged.primary_tag().or_else(|| tagged.first_tag())?;
    tag.get_string(ItemKey::Lyrics).map(fix_mojibake)
}

/// Read tags + audio properties into a [`NewTrack`]. Falls back to the filename
/// for the title when untagged.
/// Recover tag text that was written as UTF-8 bytes but labeled ISO-8859-1 (a
/// very common tagger bug; also bare ID3v1, which the spec defines as Latin-1).
/// lofty honors the label and decodes each byte to U+0000..U+00FF, so genuine
/// UTF-8 comes out as mojibake (e.g. "ş" → "ÅŸ", "ü" → "Ã¼"). If the string is
/// all ≤ U+00FF and re-interpreting those chars as Latin-1 bytes yields *valid*
/// UTF-8 that differs, the bytes were UTF-8 all along — return the recovered
/// text. Correctly-decoded Latin-1 (e.g. "café") has isolated high bytes that are
/// not valid UTF-8, so `from_utf8` fails and the text is left untouched.
fn fix_mojibake(s: &str) -> String {
    if s.is_ascii() || !s.chars().all(|c| (c as u32) <= 0xFF) {
        return s.to_string();
    }
    let bytes: Vec<u8> = s.chars().map(|c| c as u8).collect();
    match std::str::from_utf8(&bytes) {
        Ok(recovered) if recovered != s => recovered.to_string(),
        _ => s.to_string(),
    }
}

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
                nt.title = fix_mojibake(&t);
            }
        }
        if let Some(a) = tag.artist() {
            nt.artists = split_multi(&fix_mojibake(&a));
        }
        nt.album = tag
            .album()
            .map(|a| fix_mojibake(&a))
            .filter(|s| !s.is_empty());
        nt.album_artist = tag
            .get_string(ItemKey::AlbumArtist)
            .map(fix_mojibake)
            .filter(|s| !s.is_empty());
        if let Some(g) = tag.genre() {
            nt.genres = split_multi(&fix_mojibake(&g));
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

/// Editable tag fields for write-back. Empty strings clear the field; a
/// multi-value artist/genre may be entered with `;` separators (re-split on
/// the next scan via [`split_multi`]).
#[derive(Debug, Clone, Default)]
pub struct TagEdit {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_artist: String,
    pub genre: String,
    pub year: Option<i64>,
    pub track_no: Option<i64>,
}

/// Write `edit` back into `path`'s primary tag (creating one if the file has
/// none). The file's audio data is untouched.
pub fn write_tags(path: &Path, edit: &TagEdit) -> anyhow::Result<()> {
    let mut tagged = lofty::read_from_path(path)?;
    if tagged.primary_tag().is_none() {
        let tt = tagged.primary_tag_type();
        tagged.insert_tag(Tag::new(tt));
    }
    let tag = tagged
        .primary_tag_mut()
        .ok_or_else(|| anyhow::anyhow!("this file format does not support tags"))?;

    let set_or_clear = |tag: &mut Tag, value: &str, key: ItemKey| {
        let v = value.trim();
        if v.is_empty() {
            tag.remove_key(key);
        } else {
            tag.insert_text(key, v.to_string());
        }
    };
    set_or_clear(tag, &edit.title, ItemKey::TrackTitle);
    set_or_clear(tag, &edit.artist, ItemKey::TrackArtist);
    set_or_clear(tag, &edit.album, ItemKey::AlbumTitle);
    set_or_clear(tag, &edit.album_artist, ItemKey::AlbumArtist);
    set_or_clear(tag, &edit.genre, ItemKey::Genre);

    match edit.year {
        Some(y) if y > 0 => {
            tag.insert_text(ItemKey::Year, y.to_string());
        }
        _ => tag.remove_key(ItemKey::Year),
    }
    match edit.track_no {
        Some(n) if n > 0 => tag.set_track(n as u32),
        _ => tag.remove_track(),
    }

    tag.save_to_path(path, WriteOptions::default())?;
    Ok(())
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

    #[test]
    fn mojibake_recovers_utf8_mislabeled_as_latin1() {
        // What lofty produces when UTF-8 tag bytes are labeled ISO-8859-1: each
        // UTF-8 byte mapped 1:1 to a code point. Recover the original.
        let moji: String = "Şarkı".bytes().map(|b| b as char).collect();
        assert_ne!(moji, "Şarkı");
        assert_eq!(fix_mojibake(&moji), "Şarkı");

        let moji2: String = "Güneş — AC/DC".bytes().map(|b| b as char).collect();
        assert_eq!(fix_mojibake(&moji2), "Güneş — AC/DC");
    }

    #[test]
    fn mojibake_leaves_clean_text_untouched() {
        // ASCII and correctly-decoded Latin-1 (lone high bytes, not valid UTF-8)
        // must pass through unchanged — no false "recovery".
        assert_eq!(fix_mojibake("Hello World"), "Hello World");
        assert_eq!(fix_mojibake("café"), "café"); // é = lone 0xE9, not valid UTF-8
        assert_eq!(fix_mojibake("Şarkı"), "Şarkı"); // already-correct UTF-8
        assert_eq!(fix_mojibake(""), "");
    }
}
