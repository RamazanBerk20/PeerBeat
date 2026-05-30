//! Browse views: Albums / Artists / Genres / Years / Recently-Added, and the
//! track lists within each. Track-returning queries reuse [`tracks::SELECT_ROW`].

use crate::db::tracks::{self, TrackRow};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlbumRow {
    pub id: i64,
    pub title: String,
    pub artist: String,
    pub year: Option<i64>,
    pub track_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArtistRow {
    pub id: i64,
    pub name: String,
    pub album_count: i64,
    pub track_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenreRow {
    pub id: i64,
    pub name: String,
    pub track_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YearRow {
    pub year: i64,
    pub track_count: i64,
}

pub fn browse_albums(
    conn: &Connection,
    limit: i64,
    offset: i64,
) -> rusqlite::Result<Vec<AlbumRow>> {
    let mut stmt = conn.prepare(
        "SELECT al.id, al.title, COALESCE(ar.name, '') AS artist, al.year,
                count(t.id) AS track_count
         FROM albums al
         LEFT JOIN artists ar ON ar.id = al.album_artist_id
         LEFT JOIN tracks t ON t.album_id = al.id
         GROUP BY al.id
         ORDER BY al.sort_title COLLATE NOCASE
         LIMIT ?1 OFFSET ?2",
    )?;
    let rows = stmt.query_map(params![limit, offset], |r| {
        Ok(AlbumRow {
            id: r.get(0)?,
            title: r.get(1)?,
            artist: r.get(2)?,
            year: r.get(3)?,
            track_count: r.get(4)?,
        })
    })?;
    rows.collect()
}

pub fn browse_artists(conn: &Connection) -> rusqlite::Result<Vec<ArtistRow>> {
    let mut stmt = conn.prepare(
        "SELECT ar.id, ar.name,
                count(DISTINCT t.album_id) AS album_count,
                count(DISTINCT ta.track_id) AS track_count
         FROM artists ar
         LEFT JOIN track_artists ta ON ta.artist_id = ar.id
         LEFT JOIN tracks t ON t.id = ta.track_id
         GROUP BY ar.id
         ORDER BY ar.sort_name COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(ArtistRow {
            id: r.get(0)?,
            name: r.get(1)?,
            album_count: r.get(2)?,
            track_count: r.get(3)?,
        })
    })?;
    rows.collect()
}

pub fn browse_genres(conn: &Connection) -> rusqlite::Result<Vec<GenreRow>> {
    let mut stmt = conn.prepare(
        "SELECT g.id, g.name, count(tg.track_id) AS track_count
         FROM genres g
         LEFT JOIN track_genres tg ON tg.genre_id = g.id
         GROUP BY g.id
         ORDER BY g.name COLLATE NOCASE",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(GenreRow {
            id: r.get(0)?,
            name: r.get(1)?,
            track_count: r.get(2)?,
        })
    })?;
    rows.collect()
}

pub fn browse_years(conn: &Connection) -> rusqlite::Result<Vec<YearRow>> {
    let mut stmt = conn.prepare(
        "SELECT year, count(*) AS track_count FROM tracks
         WHERE year IS NOT NULL GROUP BY year ORDER BY year DESC",
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(YearRow {
            year: r.get(0)?,
            track_count: r.get(1)?,
        })
    })?;
    rows.collect()
}

fn track_list(conn: &Connection, tail: &str, p: i64) -> rusqlite::Result<Vec<TrackRow>> {
    let sql = format!("{} {}", tracks::SELECT_ROW, tail);
    let mut stmt = conn.prepare(&sql)?;
    let rows = stmt.query_map(params![p], tracks::map_row)?;
    rows.collect()
}

pub fn album_tracks(conn: &Connection, album_id: i64) -> rusqlite::Result<Vec<TrackRow>> {
    track_list(
        conn,
        "tracks t LEFT JOIN albums al ON al.id = t.album_id \
         WHERE t.album_id = ?1 ORDER BY t.disc_no, t.track_no, t.title",
        album_id,
    )
}

pub fn artist_tracks(conn: &Connection, artist_id: i64) -> rusqlite::Result<Vec<TrackRow>> {
    track_list(
        conn,
        "tracks t LEFT JOIN albums al ON al.id = t.album_id \
         JOIN track_artists ta ON ta.track_id = t.id \
         WHERE ta.artist_id = ?1 GROUP BY t.id ORDER BY t.title COLLATE NOCASE",
        artist_id,
    )
}

pub fn genre_tracks(conn: &Connection, genre_id: i64) -> rusqlite::Result<Vec<TrackRow>> {
    track_list(
        conn,
        "tracks t LEFT JOIN albums al ON al.id = t.album_id \
         JOIN track_genres tg ON tg.track_id = t.id \
         WHERE tg.genre_id = ?1 GROUP BY t.id ORDER BY t.title COLLATE NOCASE",
        genre_id,
    )
}

pub fn tracks_by_year(conn: &Connection, year: i64) -> rusqlite::Result<Vec<TrackRow>> {
    track_list(
        conn,
        "tracks t LEFT JOIN albums al ON al.id = t.album_id \
         WHERE t.year = ?1 ORDER BY t.title COLLATE NOCASE",
        year,
    )
}

pub fn recently_added(conn: &Connection, limit: i64) -> rusqlite::Result<Vec<TrackRow>> {
    track_list(
        conn,
        "tracks t LEFT JOIN albums al ON al.id = t.album_id \
         ORDER BY t.added_at DESC LIMIT ?1",
        limit,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::tracks::{upsert_track, NewTrack};
    use crate::db::Db;

    fn track(path: &str, title: &str, artist: &str, album: &str, year: i64) -> NewTrack {
        NewTrack {
            path: path.into(),
            normalized_path: path.into(),
            title: title.into(),
            artists: vec![artist.into()],
            album: Some(album.into()),
            album_artist: Some(artist.into()),
            genres: vec!["Rock".into()],
            year: Some(year),
            added_at: 1,
            ..Default::default()
        }
    }

    #[test]
    fn browse_groups_and_track_lists() {
        let db = Db::open_in_memory().unwrap();
        let c = db.conn();
        upsert_track(
            c,
            &track("/m/1.flac", "A", "Radiohead", "OK Computer", 1997),
        )
        .unwrap();
        upsert_track(
            c,
            &track("/m/2.flac", "B", "Radiohead", "OK Computer", 1997),
        )
        .unwrap();
        upsert_track(
            c,
            &track("/m/3.flac", "C", "Radiohead", "In Rainbows", 2007),
        )
        .unwrap();

        let albums = browse_albums(c, 50, 0).unwrap();
        assert_eq!(albums.len(), 2);
        let okc = albums.iter().find(|a| a.title == "OK Computer").unwrap();
        assert_eq!(okc.track_count, 2);
        assert_eq!(okc.artist, "Radiohead");

        let artists = browse_artists(c).unwrap();
        assert_eq!(artists.len(), 1);
        assert_eq!(artists[0].track_count, 3);
        assert_eq!(artists[0].album_count, 2);

        let years = browse_years(c).unwrap();
        assert_eq!(years[0].year, 2007); // desc
        assert_eq!(album_tracks(c, okc.id).unwrap().len(), 2);
        assert_eq!(artist_tracks(c, artists[0].id).unwrap().len(), 3);
        assert_eq!(recently_added(c, 10).unwrap().len(), 3);
    }
}
