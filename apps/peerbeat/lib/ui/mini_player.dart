import 'package:flutter/material.dart';

import '../playback/player.dart';
import 'library_home.dart' show fmtDuration;

/// Persistent transport bar bound to the [player] singleton. Hidden when nothing
/// is loaded.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

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
        final posMs = player.position.inMilliseconds.clamp(0, maxMs);
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
                    value: posMs.toDouble(),
                    onChanged: (v) =>
                        player.seek(Duration(milliseconds: v.toInt())),
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
                              '   ${fmtDuration(posMs)} / ${fmtDuration(durMs)}',
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
                        onPressed: player.hasNext ? player.next : null,
                        icon: const Icon(Icons.skip_next),
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
