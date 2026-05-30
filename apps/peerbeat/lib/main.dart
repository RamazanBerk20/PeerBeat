import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'audio/audio_engine.dart';
import 'src/rust/api/library.dart';
import 'src/rust/db/tracks.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final dir = await getApplicationSupportDirectory();
  await libraryOpen(dbPath: '${dir.path}${Platform.pathSeparator}library.db');
  runApp(const PeerBeatApp());
}

class PeerBeatApp extends StatelessWidget {
  const PeerBeatApp({super.key});

  static const _seed = Color(0xFF2BD9C6); // neon teal from the PeerBeat icon

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme(Brightness b) =>
        ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    return MaterialApp(
      title: 'PeerBeat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme(Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: scheme(Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const LibraryScreen(),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final AudioEngine _engine = AudioEngine.forPlatform();

  List<TrackRow> _tracks = [];
  int _count = 0;
  String _query = '';
  bool _busy = false;

  // playback
  TrackRow? _current;
  bool _playing = false;
  int _posMs = 0;
  int _durMs = 0;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _posSub = _engine.positionStream.listen((p) {
      if (mounted) setState(() => _posMs = p.inMilliseconds);
    });
    _playSub = _engine.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final tracks = _query.trim().isEmpty
        ? await libraryBrowseSongs(limit: 500, offset: 0)
        : await librarySearch(query: _query.trim(), limit: 500);
    final count = await libraryTrackCount();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _count = count;
    });
  }

  void _play(TrackRow t) {
    _engine.playPath(t.path, duration: Duration(milliseconds: t.durationMs));
    setState(() {
      _current = t;
      _playing = true;
      _posMs = 0;
      _durMs = t.durationMs;
    });
  }

  void _togglePlay() {
    if (_current == null) return;
    if (_playing) {
      _engine.pause();
    } else {
      _engine.resume();
    }
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
      final report = await libraryScan(path: path.trim());
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scanned: ${report.added} added, ${report.updated} updated, '
            '${report.skipped} unchanged, ${report.errors} errors',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerBeat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _busy
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SearchBar(
              hintText: 'Search songs, artists, albums…',
              leading: const Icon(Icons.search),
              onChanged: (v) {
                _query = v;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: _tracks.isEmpty
                ? _EmptyState(onScan: _busy ? null : _scan)
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (_, i) {
                      final t = _tracks[i];
                      return _TrackTile(
                        track: t,
                        selected: _current?.id == t.id,
                        onTap: () => _play(t),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _current == null
          ? null
          : _MiniPlayer(
              track: _current!,
              playing: _playing,
              posMs: _posMs,
              durMs: _durMs == 0 ? _current!.durationMs : _durMs,
              onToggle: _togglePlay,
              onSeek: (ms) {
                _engine.seek(Duration(milliseconds: ms));
                setState(() => _posMs = ms);
              },
            ),
    );
  }
}

String _fmt(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    this.selected = false,
  });
  final TrackRow track;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = [
      if (track.artist.isNotEmpty) track.artist,
      if (track.album.isNotEmpty) track.album,
    ].join(' • ');
    return ListTile(
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
      leading: CircleAvatar(
        backgroundColor: selected ? cs.primary : null,
        child: Icon(
          selected ? Icons.equalizer : Icons.music_note,
          color: selected ? cs.onPrimary : null,
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(_fmt(track.durationMs)),
      onTap: onTap,
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.track,
    required this.playing,
    required this.posMs,
    required this.durMs,
    required this.onToggle,
    required this.onSeek,
  });

  final TrackRow track;
  final bool playing;
  final int posMs;
  final int durMs;
  final VoidCallback onToggle;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = durMs <= 0 ? 1.0 : durMs.toDouble();
    final value = posMs.clamp(0, durMs <= 0 ? 1 : durMs).toDouble();
    return Material(
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                min: 0,
                max: max,
                value: value > max ? max : value,
                onChanged: (v) => onSeek(v.toInt()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.music_note, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${track.artist.isEmpty ? 'Unknown' : track.artist}'
                          '   ${_fmt(posMs)} / ${_fmt(durMs)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: onToggle,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onScan});
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Your library is empty'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Scan a folder'),
          ),
        ],
      ),
    );
  }
}
