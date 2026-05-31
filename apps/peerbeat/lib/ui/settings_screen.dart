import 'package:flutter/material.dart';

import '../playback/player.dart';

/// App settings. Currently houses audio normalization (ReplayGain); the custom
/// DSP engine settings (EQ, output device, crossfade) land here as P4 lands.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final rgOn = player.replayGainMode != ReplayGainMode.off;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Audio', style: text.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ReplayGain', style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Even out perceived loudness between tracks using gain '
                      'tags written by taggers like foobar2000 / rsgain.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ReplayGainMode>(
                      segments: const [
                        ButtonSegment(
                          value: ReplayGainMode.off,
                          label: Text('Off'),
                        ),
                        ButtonSegment(
                          value: ReplayGainMode.track,
                          label: Text('Track'),
                        ),
                        ButtonSegment(
                          value: ReplayGainMode.album,
                          label: Text('Album'),
                        ),
                      ],
                      selected: {player.replayGainMode},
                      onSelectionChanged: (s) =>
                          player.setReplayGainMode(s.first),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Pre-amp'),
                        Expanded(
                          child: Slider(
                            min: -15,
                            max: 15,
                            divisions: 60,
                            label:
                                '${player.replayGainPreampDb.toStringAsFixed(1)} dB',
                            value: player.replayGainPreampDb,
                            onChanged: rgOn ? player.setReplayGainPreamp : null,
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${player.replayGainPreampDb.toStringAsFixed(1)} dB',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('About', style: text.titleLarge),
            const Card(
              child: ListTile(
                leading: Icon(Icons.music_note),
                title: Text('PeerBeat'),
                subtitle: Text('Local + LAN music player'),
              ),
            ),
          ],
        );
      },
    );
  }
}
