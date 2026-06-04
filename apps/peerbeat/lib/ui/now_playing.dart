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
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.expand_more),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('Now Playing'),
            centerTitle: true,
          ),
          body: SafeArea(
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
                      const VerticalDivider(width: 1),
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
    final posMs = (dragMs ?? player.position.inMilliseconds.toDouble())
        .clamp(0, maxMs.toDouble())
        .toDouble();
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
          Slider(
            min: 0,
            max: maxMs.toDouble(),
            value: posMs,
            onChanged: onDragChanged,
            onChangeEnd: onDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmtDuration(posMs.round()), style: text.labelMedium),
                Text(fmtDuration(durMs), style: text.labelMedium),
              ],
            ),
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
        if (localTrack)
          _FavoriteButton(key: ValueKey(cur.id), trackId: cur.id),
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
