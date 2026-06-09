import 'package:flutter/material.dart' hide RepeatMode;

import '../l10n/app_localizations.dart';
import '../playback/player.dart';
import 'library_home.dart' show TrackArt, fmtDuration;
import 'now_playing.dart';

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
        return Material(
          color: cs.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only the scrubber follows the live position (~5x/s). The rest
                // of the bar — including the tooltipped transport buttons — is
                // built from state that changes rarely, so position ticks don't
                // churn the OverlayPortal-backed tooltips (which crashes the
                // Overlay with a `_skipMarkNeedsLayout` assertion).
                ValueListenableBuilder<Duration>(
                  valueListenable: player.positionNotifier,
                  builder: (context, pos, _) {
                    final posMs = (_dragMs ?? pos.inMilliseconds.toDouble())
                        .clamp(0, maxMs.toDouble())
                        .toDouble();
                    return SliderTheme(
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
                        semanticFormatterCallback: (v) => AppLocalizations.of(
                          context,
                        ).positionLabel(fmtDuration(v.round())),
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
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context).seekFailed(e),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NowPlayingScreen(),
                              fullscreenDialog: true,
                            ),
                          ),
                          child: Row(
                            children: [
                              TrackArt(track: t, size: 44),
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
                                    // Live elapsed/total — its own listener so
                                    // only this label repaints on each tick.
                                    ValueListenableBuilder<Duration>(
                                      valueListenable: player.positionNotifier,
                                      builder: (context, pos, _) {
                                        final posMs =
                                            (_dragMs ??
                                                    pos.inMilliseconds
                                                        .toDouble())
                                                .clamp(0, maxMs.toDouble());
                                        return Text(
                                          '${t.artist.isEmpty ? 'Unknown' : t.artist}'
                                          '   ${fmtDuration(posMs.round())} / ${fmtDuration(durMs)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Compact transport only — prev · play/pause · next. The
                      // full set (shuffle, repeat, favourite, volume, speed)
                      // lives on the Now Playing screen (tap the bar to open).
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: AppLocalizations.of(context).commonPrevious,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: player.hasPrevious ? player.previous : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      IconButton.filled(
                        tooltip: player.playing ? 'Pause' : 'Play',
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: player.toggle,
                        icon: Icon(
                          player.playing ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context).commonNext,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
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
