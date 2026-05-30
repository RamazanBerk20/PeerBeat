import 'dart:io';

import 'package:flutter/material.dart';

import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/browse.dart';
import '../src/rust/db/tracks.dart';
import 'mini_player.dart';

String fmtDuration(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key});

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  String _query = '';
  bool _busy = false;
  int _version = 0; // bumped after a scan to refresh tab data
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final c = await libraryTrackCount();
    if (mounted) setState(() => _count = c);
  }

  Future<void> _scan() async {
    final controller = TextEditingController(
      text: Platform.environment['HOME'] ?? '',
    );
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan a music folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder path',
            hintText: '/home/you/Music',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Scan'),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await libraryScan(path: path.trim());
      await _refreshCount();
      if (mounted) {
        setState(() => _version++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scanned: ${r.added} added, ${r.updated} updated, '
              '${r.skipped} unchanged, ${r.errors} errors',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PeerBeat'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '$_count tracks',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Scan folder',
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(searching ? 64 : 112),
            child: Column(
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: SearchBar(
                    hintText: 'Search songs, artists, albums…',
                    leading: const Icon(Icons.search),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (!searching)
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Songs'),
                      Tab(text: 'Albums'),
                      Tab(text: 'Artists'),
                      Tab(text: 'Genres'),
                      Tab(text: 'Recent'),
                    ],
                  ),
              ],
            ),
          ),
        ),
        body: searching
            ? _SearchResults(query: _query.trim())
            : TabBarView(
                children: [
                  _SongsTab(key: ValueKey('songs$_version')),
                  _AlbumsTab(key: ValueKey('albums$_version')),
                  _ArtistsTab(key: ValueKey('artists$_version')),
                  _GenresTab(key: ValueKey('genres$_version')),
                  _RecentTab(key: ValueKey('recent$_version')),
                ],
              ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}

// ── Track list (reused by tabs, search, and detail pages) ───────────────────

class TrackListView extends StatelessWidget {
  const TrackListView({super.key, required this.tracks});
  final List<TrackRow> tracks;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Center(child: Text('Nothing here yet'));
    }
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (_, i) {
          final t = tracks[i];
          final selected = player.current?.id == t.id;
          final cs = Theme.of(context).colorScheme;
          return ListTile(
            selected: selected,
            leading: CircleAvatar(
              backgroundColor: selected ? cs.primary : null,
              child: Icon(
                selected ? Icons.equalizer : Icons.music_note,
                color: selected ? cs.onPrimary : null,
              ),
            ),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (t.artist.isNotEmpty) t.artist,
                if (t.album.isNotEmpty) t.album,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(fmtDuration(t.durationMs)),
            onTap: () => player.playQueue(tracks, i),
          );
        },
      ),
    );
  }
}

/// Generic async loader → TrackListView.
class _TracksFuture extends StatelessWidget {
  const _TracksFuture(this.load, {super.key});
  final Future<List<TrackRow>> Function() load;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackRow>>(
      future: load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return TrackListView(tracks: snap.data!);
      },
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({super.key});
  @override
  Widget build(BuildContext context) =>
      _TracksFuture(() => libraryBrowseSongs(limit: 5000, offset: 0));
}

class _RecentTab extends StatelessWidget {
  const _RecentTab({super.key});
  @override
  Widget build(BuildContext context) =>
      _TracksFuture(() => libraryRecentlyAdded(limit: 200));
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) => _TracksFuture(
    () => librarySearch(query: query, limit: 500),
    key: ValueKey(query),
  );
}

// ── Albums / Artists / Genres ───────────────────────────────────────────────

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AlbumRow>>(
      future: libraryBrowseAlbums(limit: 5000, offset: 0),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final albums = snap.data!;
        if (albums.isEmpty) return const Center(child: Text('No albums'));
        return ListView.builder(
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final a = albums[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.album)),
              title: Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (a.artist.isNotEmpty) a.artist,
                  if (a.year != null) '${a.year}',
                ].join(' • '),
              ),
              trailing: Text('${a.trackCount}'),
              onTap: () => _openTracks(
                context,
                a.title,
                () => libraryAlbumTracks(albumId: a.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ArtistRow>>(
      future: libraryBrowseArtists(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final artists = snap.data!;
        if (artists.isEmpty) return const Center(child: Text('No artists'));
        return ListView.builder(
          itemCount: artists.length,
          itemBuilder: (_, i) {
            final a = artists[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${a.albumCount} albums • ${a.trackCount} tracks'),
              onTap: () => _openTracks(
                context,
                a.name,
                () => libraryArtistTracks(artistId: a.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _GenresTab extends StatelessWidget {
  const _GenresTab({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GenreRow>>(
      future: libraryBrowseGenres(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final genres = snap.data!;
        if (genres.isEmpty) return const Center(child: Text('No genres'));
        return ListView.builder(
          itemCount: genres.length,
          itemBuilder: (_, i) {
            final g = genres[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.label)),
              title: Text(g.name),
              trailing: Text('${g.trackCount}'),
              onTap: () => _openTracks(
                context,
                g.name,
                () => libraryGenreTracks(genreId: g.id),
              ),
            );
          },
        );
      },
    );
  }
}

void _openTracks(
  BuildContext context,
  String title,
  Future<List<TrackRow>> Function() load,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _TracksFuture(load),
        bottomNavigationBar: const MiniPlayer(),
      ),
    ),
  );
}
