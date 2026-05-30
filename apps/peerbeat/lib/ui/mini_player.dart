import 'package:flutter/material.dart' hide RepeatMode;

import '../playback/player.dart';
import 'library_home.dart' show fmtDuration;

/// Persistent transport bar bound to the [player] singleton. Hidden when nothing
/// is loaded.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static const _endSeekEpsilon = Duration(milliseconds: 250);
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final t = player.current;
        if (t == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final durMs = player.duration.inMilliseconds;
        final maxMs = durMs <= 0 ? 1 : durMs;
        final posMs = (_dragMs ?? player.position.inMilliseconds.toDouble())
            .clamp(0, maxMs.toDouble())
            .toDouble();
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs.toDouble(),
                    value: posMs,
                    onChanged: (v) => setState(() => _dragMs = v),
                    onChangeEnd: (v) async {
                      final requested = Duration(milliseconds: v.toInt());
                      final duration = Duration(milliseconds: durMs);
                      final target =
                          duration > _endSeekEpsilon &&
                              requested >= duration - _endSeekEpsilon
                          ? duration - _endSeekEpsilon
                          : requested;
                      setState(() => _dragMs = null);
                      try {
                        await player.seek(target);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Seek failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(
                          Icons.music_note,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${t.artist.isEmpty ? 'Unknown' : t.artist}'
                              '   ${fmtDuration(posMs.round())} / ${fmtDuration(durMs)}',
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
                      IconButton(
                        tooltip: 'Shuffle',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => player.setShuffle(!player.shuffle),
                        icon: Icon(
                          Icons.shuffle,
                          color: player.shuffle ? cs.primary : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        visualDensity: VisualDensity.compact,
                        onPressed: player.hasPrevious ? player.previous : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      IconButton.filled(
                        onPressed: player.toggle,
                        icon: Icon(
                          player.playing ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        visualDensity: VisualDensity.compact,
                        onPressed: player.hasNext ? player.next : null,
                        icon: const Icon(Icons.skip_next),
                      ),
                      IconButton(
                        tooltip: switch (player.repeat) {
                          RepeatMode.off => 'Repeat off',
                          RepeatMode.all => 'Repeat all',
                          RepeatMode.one => 'Repeat one',
                        },
                        visualDensity: VisualDensity.compact,
                        onPressed: player.cycleRepeat,
                        icon: Icon(
                          player.repeat == RepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: player.repeat == RepeatMode.off
                              ? null
                              : cs.primary,
                        ),
                      ),
                      IconButton(
                        tooltip: player.muted ? 'Unmute' : 'Mute',
                        visualDensity: VisualDensity.compact,
                        onPressed: player.toggleMute,
                        icon: Icon(
                          player.muted ? Icons.volume_off : Icons.volume_up,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
