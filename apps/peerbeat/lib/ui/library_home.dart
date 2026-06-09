import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Int64List;

import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/browse.dart';
import '../src/rust/db/folders.dart';
import '../src/rust/db/playlists.dart';
import '../src/rust/db/smart.dart';
import '../src/rust/db/tracks.dart';
import 'edit_metadata.dart';
import 'mini_player.dart';
import 'network_screen.dart';
import 'settings_screen.dart';
import 'smart_playlist.dart';
import 'text_input_dialog.dart';

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
  int _section = 0;
  String _query = '';
  bool _busy = false;
  int _version = 0; // bumped after a scan to refresh tab data
  int _count = 0;
  bool _dragging = false; // a folder is being dragged over the window

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
    final path = await _pickMusicFolder(context);
    if (path == null || path.trim().isEmpty) return;
    await _scanPath(path.trim());
  }

  /// Add + scan a single folder, refreshing the count and the visible tabs.
  Future<void> _scanPath(String path) async {
    setState(() => _busy = true);
    try {
      final r = await libraryScan(path: path);
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

  /// Desktop drag-and-drop: dropping a folder onto the library adds + scans it
  /// (a dropped file resolves to its containing folder). Only wired on desktop.
  static bool get _dropSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Future<void> _onFolderDrop(List<String> paths) async {
    final dirs = <String>{};
    for (final p in paths) {
      if (await Directory(p).exists()) {
        dirs.add(p);
      } else if (await File(p).exists()) {
        dirs.add(File(p).parent.path);
      }
    }
    for (final d in dirs) {
      await _scanPath(d);
    }
  }

  /// Wrap the body in a desktop [DropTarget] so a dragged-in folder is added +
  /// scanned, with a highlight while dragging. No-op on mobile.
  Widget _wrapDrop(Widget child) {
    if (!_dropSupported) return child;
    final cs = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        unawaited(_onFolderDrop([for (final f in detail.files) f.path]));
      },
      child: Stack(
        children: [
          child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: cs.primary.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.create_new_folder_outlined, size: 40),
                          SizedBox(height: 12),
                          Text('Drop a folder to add it to your library'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _manageFolders() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _FoldersDialog(),
    );
    if (changed == true && mounted) {
      await _refreshCount();
      setState(() => _version++);
    }
  }

  Future<String?> _pickMusicFolder(BuildContext context) async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Scan a music folder',
        initialDirectory: Platform.environment['HOME'],
      );
    } catch (_) {
      if (!context.mounted) return null;
      return promptText(
        context,
        title: 'Scan a music folder',
        initialText: Platform.environment['HOME'] ?? '',
        label: 'Folder path',
        hint: '/home/you/Music',
        confirmLabel: 'Scan',
      );
    }
  }

  static const _destinations = [
    (Icons.library_music_outlined, Icons.library_music, 'Songs'),
    (Icons.queue_music_outlined, Icons.queue_music, 'Playlists'),
    (Icons.wifi_tethering_outlined, Icons.wifi_tethering, 'Network'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = switch (_section) {
      0 => 'Songs',
      1 => 'Playlists',
      2 => 'Network',
      _ => 'Settings',
    };
    final section = switch (_section) {
      0 => _SongsSection(
        query: _query,
        busy: _busy,
        version: _version,
        onQueryChanged: (v) => setState(() => _query = v),
      ),
      1 => _PlaylistsTab(key: ValueKey('playlists$_version')),
      2 => const NetworkPanel(),
      _ => const SettingsScreen(),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rail on tablet/desktop widths; bottom NavigationBar on phones.
        final wide = constraints.maxWidth >= 600;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (_section == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      '$_count tracks',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              if (_section == 0)
                IconButton(
                  tooltip: 'Library folders',
                  onPressed: _busy ? null : _manageFolders,
                  icon: const Icon(Icons.folder_outlined),
                ),
              if (_section == 0)
                IconButton(
                  tooltip: 'Scan folder',
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
            ],
          ),
          body: _wrapDrop(
            wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _section,
                        onDestinationSelected: (v) =>
                            setState(() => _section = v),
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final (icon, sel, label) in _destinations)
                            NavigationRailDestination(
                              icon: Icon(icon),
                              selectedIcon: Icon(sel),
                              label: Text(label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: section),
                    ],
                  )
                : section,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              if (!wide)
                NavigationBar(
                  selectedIndex: _section,
                  onDestinationSelected: (v) => setState(() => _section = v),
                  destinations: [
                    for (final (icon, sel, label) in _destinations)
                      NavigationDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(sel),
                        label: label,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Manage library source folders: list, rescan-all (prunes deleted files), and
/// remove. Pops `true` if anything changed so the caller can refresh.
class _FoldersDialog extends StatefulWidget {
  const _FoldersDialog();

  @override
  State<_FoldersDialog> createState() => _FoldersDialogState();
}

class _FoldersDialogState extends State<_FoldersDialog> {
  late Future<List<FolderRow>> _future = libraryFolders();
  bool _changed = false;
  bool _busy = false;

  // Block body (not an arrow): `_future = libraryFolders()` is an assignment
  // *expression* whose value is the Future, so an arrow closure would return it
  // and trip setState()'s "callback returned a Future" assertion.
  void _reload() => setState(() {
    _future = libraryFolders();
  });

  Future<void> _rescanAll() async {
    setState(() => _busy = true);
    try {
      final r = await libraryRescanAll();
      if (!mounted) return;
      _changed = true;
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rescan: ${r.added} added, ${r.updated} updated, '
              '${r.removed} removed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rescan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(FolderRow f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove folder?'),
        content: Text(
          'Forget "${f.path}" and remove its tracks from the library? '
          'Files on disk are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await libraryRemoveFolder(folderId: f.id);
    if (!mounted) return;
    _changed = true;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Library folders')),
          TextButton.icon(
            onPressed: _busy ? null : _rescanAll,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Rescan all'),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 320,
        child: FutureBuilder<List<FolderRow>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final folders = snap.data!;
            if (folders.isEmpty) {
              return const Center(
                child: Text('No folders yet — use "Scan folder".'),
              );
            }
            return ListView.builder(
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final f = folders[i];
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(
                    f.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(f),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _changed),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _SongsSection extends StatelessWidget {
  const _SongsSection({
    required this.query,
    required this.busy,
    required this.version,
    required this.onQueryChanged,
  });

  final String query;
  final bool busy;
  final int version;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SearchBar(
              hintText: 'Search songs, artists, albums…',
              leading: const Icon(Icons.search),
              onChanged: onQueryChanged,
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
          Expanded(
            child: searching
                ? _SearchResults(query: query.trim())
                : TabBarView(
                    children: [
                      _SongsTab(key: ValueKey('songs$version')),
                      _AlbumsTab(key: ValueKey('albums$version')),
                      _ArtistsTab(key: ValueKey('artists$version')),
                      _GenresTab(key: ValueKey('genres$version')),
                      _RecentTab(key: ValueKey('recent$version')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Track list (reused by tabs, search, and detail pages) ───────────────────

/// Album-cover thumbnail for a track: shows the scan-cached art when present,
/// otherwise a music-note placeholder. [selected] tints it while playing.
/// Always a rounded square so art-present and art-absent rows align.
class TrackArt extends StatelessWidget {
  const TrackArt({
    super.key,
    required this.track,
    this.selected = false,
    this.size = 40,
  });

  final TrackRow track;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(size * 0.2);
    final art = track.artPath;
    final Widget visual;
    if (art != null && art.isNotEmpty) {
      visual = ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(art),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Decorative: every use sits beside the track's title/artist text.
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _placeholder(cs, radius),
        ),
      );
    } else {
      visual = _placeholder(cs, radius);
    }
    // When selected, the art slot doubles as the "now playing" indicator
    // (equalizer glyph / accent) — announce that to screen readers; otherwise
    // the artwork is decorative and stays excluded.
    return selected ? Semantics(label: 'Now playing', child: visual) : visual;
  }

  Widget _placeholder(ColorScheme cs, BorderRadius radius) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: radius,
    ),
    child: Icon(
      selected ? Icons.equalizer : Icons.music_note,
      size: size * 0.55,
      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
    ),
  );
}

class TrackListView extends StatefulWidget {
  const TrackListView({super.key, required this.tracks, this.onEndReached});
  final List<TrackRow> tracks;

  /// Optional infinite-scroll hook: called as the list nears its end so the
  /// caller can append the next page (it must guard against re-entrancy).
  final Future<void> Function()? onEndReached;

  @override
  State<TrackListView> createState() => _TrackListViewState();
}

class _TrackListViewState extends State<TrackListView> {
  late List<TrackRow> _tracks = List.of(widget.tracks);
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.onEndReached == null || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 800) {
      widget.onEndReached!.call();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrackListView old) {
    super.didUpdateWidget(old);
    if (!identical(old.tracks, widget.tracks)) {
      _tracks = List.of(widget.tracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tracks.isEmpty) {
      return const Center(child: Text('Nothing here yet'));
    }
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => ListView.builder(
        controller: _scroll,
        itemCount: _tracks.length,
        itemBuilder: (_, i) {
          final t = _tracks[i];
          final selected = player.current?.id == t.id;
          return ListTile(
            selected: selected,
            leading: TrackArt(track: t, selected: selected),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (t.artist.isNotEmpty) t.artist,
                if (t.album.isNotEmpty) t.album,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmtDuration(t.durationMs)),
                PopupMenuButton<String>(
                  tooltip: 'Track actions',
                  onSelected: (value) => _handleTrackAction(context, value, t),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'play_next', child: Text('Play next')),
                    PopupMenuItem(
                      value: 'add_queue',
                      child: Text('Add to queue'),
                    ),
                    PopupMenuItem(
                      value: 'add_playlist',
                      child: Text('Add to playlist'),
                    ),
                    PopupMenuItem(value: 'edit', child: Text('Edit metadata')),
                  ],
                ),
              ],
            ),
            onTap: () async {
              try {
                await player.playQueue(_tracks, i);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playback failed: $e')),
                  );
                }
              }
            },
            // Long-press opens the same actions as the ⋮ menu (better on mobile,
            // where the small trailing target is hard to hit).
            onLongPress: () => _showTrackMenu(context, t),
          );
        },
      ),
    );
  }

  /// The track action menu as a bottom sheet — the long-press equivalent of the
  /// trailing ⋮ [PopupMenuButton]. Same actions, same handler.
  Future<void> _showTrackMenu(BuildContext context, TrackRow track) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: TrackArt(track: track, size: 44),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: track.artist.isEmpty
                  ? null
                  : Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.queue_play_next),
              title: const Text('Play next'),
              onTap: () => Navigator.pop(ctx, 'play_next'),
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue),
              title: const Text('Add to queue'),
              onTap: () => Navigator.pop(ctx, 'add_queue'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () => Navigator.pop(ctx, 'add_playlist'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit metadata'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          ],
        ),
      ),
    );
    if (action != null && context.mounted) {
      await _handleTrackAction(context, action, track);
    }
  }

  Future<void> _handleTrackAction(
    BuildContext context,
    String value,
    TrackRow track,
  ) async {
    switch (value) {
      case 'play_next':
        player.playNext(track);
        break;
      case 'add_queue':
        player.addToQueue(track);
        break;
      case 'add_playlist':
        await _addTrackToPlaylist(context, track);
        return;
      case 'edit':
        final updated = await showEditMetadataDialog(context, track);
        if (updated != null) {
          final i = _tracks.indexWhere((x) => x.id == updated.id);
          if (i >= 0) setState(() => _tracks[i] = updated);
        }
        return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Queued "${track.title}"')));
    }
  }
}

/// Generic async loader → TrackListView. Stateful so the future is created once
/// (not on every rebuild) — change the widget `key` to force a reload.
class _TracksFuture extends StatefulWidget {
  const _TracksFuture(this.load, {super.key});
  final Future<List<TrackRow>> Function() load;

  @override
  State<_TracksFuture> createState() => _TracksFutureState();
}

class _TracksFutureState extends State<_TracksFuture> {
  late final Future<List<TrackRow>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return TrackListView(tracks: snap.data!);
      },
    );
  }
}

/// Infinite-scroll list backed by a paged loader. Loads one page up front (fast
/// even for a 50k library) and appends more as the user scrolls.
class _PaginatedTracks extends StatefulWidget {
  const _PaginatedTracks(this.loadPage);
  final Future<List<TrackRow>> Function(int limit, int offset) loadPage;

  @override
  State<_PaginatedTracks> createState() => _PaginatedTracksState();
}

class _PaginatedTracksState extends State<_PaginatedTracks> {
  static const _pageSize = 300;
  final List<TrackRow> _tracks = [];
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    _loading = true;
    try {
      final page = await widget.loadPage(_pageSize, _tracks.length);
      if (!mounted) return;
      setState(() {
        _tracks.addAll(page);
        if (page.length < _pageSize) _done = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Failed to load: $_error'));
    }
    if (_tracks.isEmpty && !_done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tracks.isEmpty && _done) {
      return const _EmptyLibrary();
    }
    // New list identity each page so TrackListView picks up the appended rows.
    return TrackListView(
      tracks: List.of(_tracks),
      onEndReached: _done ? null : _loadMore,
    );
  }
}

/// First-run / empty-library onboarding for the Songs tab.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canDrop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('Your library is empty', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              canDrop
                  ? 'Drag a music folder here, or use the scan button in the top bar to add one.'
                  : 'Tap the scan button in the top bar to add a music folder.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({super.key});
  @override
  Widget build(BuildContext context) => _PaginatedTracks(
    (limit, offset) => libraryBrowseSongs(limit: limit, offset: offset),
  );
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

// ── Playlists ──────────────────────────────────────────────────────────────

class _PlaylistsTab extends StatefulWidget {
  const _PlaylistsTab({super.key});

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  int _version = 0;

  void _refresh() => setState(() => _version++);

  Future<void> _create() async {
    final name = await _playlistNameDialog(context, title: 'New playlist');
    if (name == null) return;
    await playlistCreate(name: name);
    if (mounted) _refresh();
  }

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import playlist (M3U / PLS)',
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'pls'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    try {
      final report = await playlistImport(filePath: path);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${report.matched}/${report.total} tracks'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _createSmart() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SmartPlaylistEditor()),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _editSmart(SmartPlaylistRow s) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SmartPlaylistEditor(existing: s)),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _deleteSmart(SmartPlaylistRow s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete smart playlist?'),
        content: Text('Delete "${s.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await smartPlaylistDelete(smartId: s.id);
      if (mounted) _refresh();
    }
  }

  Future<(List<PlaylistRow>, List<SmartPlaylistRow>)> _load() async {
    final manual = await playlistList();
    final smart = await smartPlaylistList();
    return (manual, smart);
  }

  /// An auto-generated list tile that opens its tracks in a full-screen list.
  Widget _autoTile(
    IconData icon,
    String name,
    Future<List<TrackRow>> Function() load,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(name),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(name)),
            body: _TracksFuture(load),
            bottomNavigationBar: const MiniPlayer(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<PlaylistRow>, List<SmartPlaylistRow>)>(
      key: ValueKey(_version),
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (playlists, smarts) = snap.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: const Text('New playlist'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _createSmart,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Smart'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Import'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Auto playlists'),
                  ),
                  _autoTile(
                    Icons.history,
                    'Recently Played',
                    () => libraryRecentlyPlayed(limit: 200),
                  ),
                  _autoTile(
                    Icons.local_fire_department,
                    'Most Played',
                    () => libraryMostPlayed(limit: 200),
                  ),
                  _autoTile(
                    Icons.fiber_new,
                    'Never Played',
                    () => libraryNeverPlayed(limit: 200),
                  ),
                  _autoTile(
                    Icons.favorite,
                    'Favorites',
                    () => libraryFavorites(limit: 500),
                  ),
                  if (playlists.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Playlists'),
                    ),
                  for (final p in playlists) _manualTile(p),
                  if (smarts.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Smart playlists'),
                    ),
                  for (final s in smarts) _smartTile(s),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _manualTile(PlaylistRow p) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.queue_music)),
    title: Text(p.name),
    subtitle: Text('${p.trackCount} tracks'),
    trailing: PopupMenuButton<String>(
      onSelected: (value) async {
        await _handlePlaylistAction(context, value, p);
        if (mounted) _refresh();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuItem(value: 'export', child: Text('Export…')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    ),
    onTap: () async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _PlaylistDetail(playlist: p)));
      if (mounted) _refresh();
    },
  );

  Widget _smartTile(SmartPlaylistRow s) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
    title: Text(s.name),
    subtitle: const Text('Smart'),
    trailing: PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') _editSmart(s);
        if (value == 'delete') _deleteSmart(s);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    ),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SmartPlaylistDetail(smart: s))),
  );
}

class _PlaylistDetail extends StatefulWidget {
  const _PlaylistDetail({required this.playlist});
  final PlaylistRow playlist;

  @override
  State<_PlaylistDetail> createState() => _PlaylistDetailState();
}

class _PlaylistDetailState extends State<_PlaylistDetail> {
  late Future<List<TrackRow>> _future = playlistTracks(
    playlistId: widget.playlist.id,
  );
  List<TrackRow> _tracks = const [];

  void _reload() {
    setState(() {
      _future = playlistTracks(playlistId: widget.playlist.id);
    });
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;
    await player.playQueue(_tracks, 0);
  }

  Future<void> _removeAt(int index) async {
    try {
      await playlistRemovePosition(
        playlistId: widget.playlist.id,
        position: index,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove track: $e')));
      return;
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _reorderTo(int oldIndex, int newIndex) async {
    final previous = _tracks;
    final next = [..._tracks];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() => _tracks = next); // optimistic — instant drag feedback
    try {
      await playlistReorderTracks(
        playlistId: widget.playlist.id,
        trackIds: Int64List.fromList(next.map((t) => t.id).toList()),
      );
    } catch (e) {
      // Roll the optimistic reorder back so the UI matches the DB, and report.
      if (!mounted) return;
      setState(() => _tracks = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reorder playlist: $e')));
      return;
    }
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            tooltip: 'Play playlist',
            onPressed: _tracks.isEmpty ? null : _playAll,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: FutureBuilder<List<TrackRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          _tracks = snap.data!;
          if (_tracks.isEmpty) {
            return const Center(child: Text('No tracks in this playlist'));
          }
          return ReorderableListView.builder(
            itemCount: _tracks.length,
            onReorderItem: _reorderTo,
            itemBuilder: (_, i) {
              final t = _tracks[i];
              return ListTile(
                // ObjectKey (per-row instance) is unique even if the playlist
                // holds the same track twice, and stable across a reorder —
                // unlike a key containing the index.
                key: ObjectKey(t),
                leading: const Icon(Icons.drag_handle),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  t.artist.isEmpty ? 'Unknown artist' : t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeAt(i),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                onTap: () => player.playQueue(_tracks, i),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

Future<void> _handlePlaylistAction(
  BuildContext context,
  String value,
  PlaylistRow playlist,
) async {
  switch (value) {
    case 'rename':
      final name = await _playlistNameDialog(
        context,
        title: 'Rename playlist',
        initial: playlist.name,
      );
      if (name != null) {
        await playlistRename(playlistId: playlist.id, name: name);
      }
      break;
    case 'duplicate':
      final name = await _playlistNameDialog(
        context,
        title: 'Duplicate playlist',
        initial: '${playlist.name} copy',
      );
      if (name != null) {
        await playlistDuplicate(playlistId: playlist.id, name: name);
      }
      break;
    case 'export':
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export playlist',
        fileName: '${playlist.name}.m3u',
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'pls'],
      );
      if (path != null) {
        await playlistExport(playlistId: playlist.id, filePath: path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported "${playlist.name}"')),
          );
        }
      }
      break;
    case 'delete':
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text('Delete "${playlist.name}" permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await playlistDelete(playlistId: playlist.id);
      }
      break;
  }
}

Future<void> _addTrackToPlaylist(BuildContext context, TrackRow track) async {
  final playlists = await playlistList();
  if (!context.mounted) return;
  if (playlists.isEmpty) {
    final name = await _playlistNameDialog(context, title: 'New playlist');
    if (name == null) return;
    final id = await playlistCreate(name: name);
    await playlistAddTracks(
      playlistId: id,
      trackIds: Int64List.fromList([track.id]),
    );
    return;
  }
  final picked = await showDialog<PlaylistRow>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Add to playlist'),
      children: [
        for (final p in playlists)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Text(p.name),
          ),
      ],
    ),
  );
  if (picked == null) return;
  await playlistAddTracks(
    playlistId: picked.id,
    trackIds: Int64List.fromList([track.id]),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${track.title}" to ${picked.name}')),
    );
  }
}

Future<String?> _playlistNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final name = await promptText(
    context,
    title: title,
    initialText: initial,
    label: 'Name',
    confirmLabel: 'Save',
  );
  final clean = name?.trim();
  return clean == null || clean.isEmpty ? null : clean;
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
