import 'package:flutter/material.dart' hide RepeatMode;

import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/tracks.dart';
import 'library_home.dart' show TrackArt, fmtDuration;

/// Full-screen "Now Playing": large album art, scrubber, transport, volume, and
/// the up-next queue. Bound to the [player] singleton; closes itself if the
/// queue empties.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  static const _endSeekEpsilon = Duration(milliseconds: 250);
  double? _dragMs;

  void _showLyrics(BuildContext context, int trackId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) =>
            _LyricsPanel(trackId: trackId, scrollController: controller),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => _QueueSheet(scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final t = player.current;
        if (t == null) {
          // Nothing playing (queue cleared) — pop back to the library.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.expand_more),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('Now Playing'),
            centerTitle: true,
            actions: [
              PopupMenuButton<int>(
                tooltip: player.sleepActive
                    ? 'Sleep timer: ${_fmtRemaining(player.sleepRemaining)}'
                    : 'Sleep timer',
                icon: Icon(
                  player.sleepActive ? Icons.bedtime : Icons.bedtime_outlined,
                  color: player.sleepActive ? cs.primary : null,
                ),
                onSelected: (m) =>
                    player.setSleepTimer(m == 0 ? null : Duration(minutes: m)),
                itemBuilder: (_) => [
                  if (player.sleepActive)
                    const PopupMenuItem(value: 0, child: Text('Turn off')),
                  for (final m in [15, 30, 45, 60, 90])
                    PopupMenuItem(value: m, child: Text('$m minutes')),
                ],
              ),
              IconButton(
                tooltip: 'Queue',
                icon: const Icon(Icons.queue_music),
                onPressed: () => _showQueue(context),
              ),
              if (!t.path.startsWith('http'))
                IconButton(
                  tooltip: 'Lyrics',
                  icon: const Icon(Icons.lyrics_outlined),
                  onPressed: () => _showLyrics(context, t.id),
                ),
            ],
          ),
          // Album-art-forward backdrop: the theme's primary is already derived
          // from the current art (dynamic theming), so this wash reflects it.
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.55),
                  cs.surface,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final art = _Artwork(track: t);
                  final controls = _Controls(
                    track: t,
                    dragMs: _dragMs,
                    onDragChanged: (v) => setState(() => _dragMs = v),
                    onDragEnd: _onSeekEnd,
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Center(child: art)),
                        Expanded(child: controls),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(flex: 5, child: Center(child: art)),
                      Expanded(flex: 6, child: controls),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSeekEnd(double v) async {
    final durMs = player.duration.inMilliseconds;
    final requested = Duration(milliseconds: v.toInt());
    final duration = Duration(milliseconds: durMs);
    final target =
        duration > _endSeekEpsilon && requested >= duration - _endSeekEpsilon
        ? duration - _endSeekEpsilon
        : requested;
    setState(() => _dragMs = null);
    try {
      await player.seek(target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seek failed: $e')));
      }
    }
  }
}

String _fmtRemaining(Duration? d) {
  if (d == null) return '';
  final m = d.inMinutes;
  return m >= 1 ? '$m min left' : '<1 min left';
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});
  final TrackRow track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide.clamp(120.0, 420.0);
          return Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(side * 0.06),
            clipBehavior: Clip.antiAlias,
            child: TrackArt(track: track, size: side),
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.track,
    required this.dragMs,
    required this.onDragChanged,
    required this.onDragEnd,
  });

  final TrackRow track;
  final double? dragMs;
  final ValueChanged<double> onDragChanged;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final durMs = player.duration.inMilliseconds;
    final maxMs = durMs <= 0 ? 1 : durMs;
    final upNext = player.upNext;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            track.title,
            style: text.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (track.artist.isNotEmpty) track.artist else 'Unknown artist',
              if (track.album.isNotEmpty) track.album,
            ].join(' • '),
            style: text.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Scrubber + elapsed/total follow the live position; the surrounding
          // controls (tooltipped transport + volume) stay out of the ~5x/s path
          // so their OverlayPortal tooltips don't churn and crash the Overlay.
          ValueListenableBuilder<Duration>(
            valueListenable: player.positionNotifier,
            builder: (context, pos, _) {
              final posMs = (dragMs ?? pos.inMilliseconds.toDouble())
                  .clamp(0, maxMs.toDouble())
                  .toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Slider(
                    min: 0,
                    max: maxMs.toDouble(),
                    value: posMs,
                    semanticFormatterCallback: (v) => fmtDuration(v.round()),
                    onChanged: onDragChanged,
                    onChangeEnd: onDragEnd,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fmtDuration(posMs.round()),
                          style: text.labelMedium,
                        ),
                        Text(fmtDuration(durMs), style: text.labelMedium),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _transportRow(cs),
          const SizedBox(height: 8),
          _volumeRow(context, cs),
          if (upNext.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Up next', style: text.titleSmall),
            ),
            const SizedBox(height: 4),
            Expanded(child: _UpNextList(tracks: upNext)),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _transportRow(ColorScheme cs) {
    final cur = player.current;
    final localTrack = cur != null && !cur.path.startsWith('http');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (localTrack) _FavoriteButton(key: ValueKey(cur.id), trackId: cur.id),
        IconButton(
          tooltip: 'Shuffle',
          isSelected: player.shuffle,
          onPressed: () => player.setShuffle(!player.shuffle),
          icon: Icon(Icons.shuffle, color: player.shuffle ? cs.primary : null),
        ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 36,
          onPressed: player.hasPrevious ? player.previous : null,
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton.filled(
          iconSize: 44,
          onPressed: player.toggle,
          icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Next',
          iconSize: 36,
          onPressed: player.hasNext ? player.next : null,
          icon: const Icon(Icons.skip_next),
        ),
        IconButton(
          tooltip: switch (player.repeat) {
            RepeatMode.off => 'Repeat off',
            RepeatMode.all => 'Repeat all',
            RepeatMode.one => 'Repeat one',
          },
          onPressed: player.cycleRepeat,
          icon: Icon(
            player.repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
            color: player.repeat == RepeatMode.off ? null : cs.primary,
          ),
        ),
      ],
    );
  }

  Widget _volumeRow(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          tooltip: player.muted ? 'Unmute' : 'Mute',
          onPressed: player.toggleMute,
          icon: Icon(player.muted ? Icons.volume_off : Icons.volume_up),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 1,
            value: (player.muted ? 0.0 : player.volume).clamp(0.0, 1.0),
            semanticFormatterCallback: (v) => '${(v * 100).round()}% volume',
            onChanged: player.setVolume,
          ),
        ),
        _speedButton(cs),
      ],
    );
  }

  Widget _speedButton(ColorScheme cs) {
    const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final active = player.speed != 1.0;
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: player.speed,
      onSelected: player.setSpeed,
      itemBuilder: (_) => [
        for (final s in presets)
          PopupMenuItem(value: s, child: Text('${_fmtSpeed(s)}×')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 20, color: active ? cs.primary : null),
            const SizedBox(width: 4),
            Text(
              '${_fmtSpeed(player.speed)}×',
              style: TextStyle(color: active ? cs.primary : null),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtSpeed(double s) =>
      s.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Full reorderable queue: drag to reorder, tap to jump, remove with the ✕.
class _QueueSheet extends StatelessWidget {
  const _QueueSheet({this.scrollController});
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final upNext = player.upNext;
        final base = player.currentIndex;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text('Up next', style: text.titleLarge),
                  const Spacer(),
                  Text('${upNext.length}', style: text.labelLarge),
                ],
              ),
            ),
            Expanded(
              child: upNext.isEmpty
                  ? const Center(child: Text('Queue is empty'))
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: upNext.length,
                      onReorderItem: player.reorderUpNext,
                      itemBuilder: (context, i) {
                        final t = upNext[i];
                        return ListTile(
                          key: ValueKey(i),
                          leading: TrackArt(track: t, size: 40),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: t.artist.isEmpty
                              ? null
                              : Text(
                                  t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.close),
                                onPressed: () => player.removeFromUpNext(i),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => player.playQueueIndex(base + 1 + i),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UpNextList extends StatelessWidget {
  const _UpNextList({required this.tracks});
  final List<TrackRow> tracks;

  @override
  Widget build(BuildContext context) {
    final base = player.currentIndex;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: TrackArt(track: t, size: 36),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: t.artist.isEmpty
              ? null
              : Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(fmtDuration(t.durationMs)),
          onTap: () => player.playQueueIndex(base + 1 + i),
        );
      },
    );
  }
}

/// Heart toggle for the current local track (keyed by track id so it reloads
/// when the track changes). Favorites only apply to local library tracks.
class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({super.key, required this.trackId});
  final int trackId;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool? _fav;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await libraryIsFavorite(trackId: widget.trackId);
      if (mounted) setState(() => _fav = f);
    } catch (_) {
      /* leave indeterminate */
    }
  }

  Future<void> _toggle() async {
    final next = !(_fav ?? false);
    setState(() => _fav = next);
    try {
      await librarySetFavorite(trackId: widget.trackId, on_: next);
    } catch (_) {
      if (mounted) setState(() => _fav = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fav = _fav ?? false;
    return IconButton(
      tooltip: fav ? 'Remove from Favorites' : 'Add to Favorites',
      onPressed: _toggle,
      icon: Icon(
        fav ? Icons.favorite : Icons.favorite_border,
        color: fav ? cs.primary : null,
      ),
    );
  }
}

typedef _LrcLine = ({Duration t, String text});

/// Parse `[mm:ss.xx]` LRC timestamps into sorted timed lines. Returns empty if
/// the text has no timestamps (caller then shows it as plain lyrics).
List<_LrcLine> _parseLrc(String raw) {
  final out = <_LrcLine>[];
  final tagRe = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  for (final line in raw.split('\n')) {
    final matches = tagRe.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.replaceAll(tagRe, '').trim();
    for (final m in matches) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final frac = m.group(3);
      final ms = frac == null
          ? 0
          : int.parse(frac.padRight(3, '0').substring(0, 3));
      out.add((
        t: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: text,
      ));
    }
  }
  out.sort((a, b) => a.t.compareTo(b.t));
  return out;
}

/// Lyrics view: synced highlighting for `.lrc`-style timestamps, else plain text.
class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({required this.trackId, this.scrollController});
  final int trackId;
  final ScrollController? scrollController;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  String? _raw;
  List<_LrcLine>? _synced;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await libraryTrackLyrics(trackId: widget.trackId);
      if (!mounted) return;
      setState(() {
        _raw = text;
        _synced = (text == null) ? null : _parseLrc(text);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final raw = _raw;
    if (raw == null || raw.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No lyrics found'),
        ),
      );
    }
    final synced = _synced;
    if (synced == null || synced.isEmpty) {
      return SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        child: Text(raw, style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: player.positionNotifier,
      builder: (context, pos, _) {
        var active = 0;
        for (var i = 0; i < synced.length; i++) {
          if (synced[i].t <= pos) {
            active = i;
          } else {
            break;
          }
        }
        final cs = Theme.of(context).colorScheme;
        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: synced.length,
          itemBuilder: (context, i) {
            final on = i == active;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                synced[i].text.isEmpty ? '♪' : synced[i].text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: on ? 18 : 15,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                  color: on ? cs.primary : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
