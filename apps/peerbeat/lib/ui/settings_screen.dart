import 'package:flutter/material.dart';

import '../playback/player.dart';
import '../src/rust/api/audio.dart' show OutputDeviceRow;
import '../src/rust/api/library.dart';
import '../src/rust/db/eq_presets.dart';

const _eqBands = [
  '31',
  '63',
  '125',
  '250',
  '500',
  '1k',
  '2k',
  '4k',
  '8k',
  '16k',
];

class _BuiltinEqPreset {
  const _BuiltinEqPreset(this.name, this.gains, {this.preamp = 0});

  final String name;
  final List<double> gains;
  final double preamp;
}

const _builtInPresets = [
  _BuiltinEqPreset('Flat', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  _BuiltinEqPreset('Rock', [4, 3, 2, -1, -2, 1, 3, 4, 4, 3], preamp: -2),
  _BuiltinEqPreset('Pop', [-1, 2, 4, 4, 1, -1, -1, 2, 3, 3], preamp: -2),
  _BuiltinEqPreset('Jazz', [3, 2, 1, 2, -1, -1, 0, 1, 2, 3], preamp: -1),
  _BuiltinEqPreset('Classical', [3, 2, 1, 0, 0, 0, 1, 2, 3, 4], preamp: -2),
];

/// App settings. Houses audio normalization and desktop DSP controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<EqPresetRow>> _customPresets = eqPresetList();
  Future<List<OutputDeviceRow>>? _outputDevices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadOutputDevices();
    });
  }

  void _reloadPresets() {
    setState(() {
      _customPresets = eqPresetList();
    });
  }

  void _reloadOutputDevices() {
    setState(() {
      _outputDevices = player.outputDevices();
    });
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save EQ preset'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Preset name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      final clean = name?.trim();
      if (clean == null || clean.isEmpty) return;
      await eqPresetCreate(
        name: clean,
        bands: player.eqGains,
        preamp: player.eqPreampDb,
      );
      _reloadPresets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save preset: $e')));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deletePreset(EqPresetRow preset) async {
    try {
      await eqPresetDelete(presetId: preset.id);
      _reloadPresets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete preset: $e')));
    }
  }

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
            _ReplayGainCard(rgOn: rgOn),
            const SizedBox(height: 12),
            _EqualizerCard(
              customPresets: _customPresets,
              onReloadPresets: _reloadPresets,
              onSavePreset: _savePreset,
              onDeletePreset: _deletePreset,
            ),
            const SizedBox(height: 12),
            _OutputDeviceCard(
              devices: _outputDevices,
              onReload: _reloadOutputDevices,
            ),
            const SizedBox(height: 12),
            const _StereoWidthCard(),
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

class _StereoWidthCard extends StatelessWidget {
  const _StereoWidthCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stereo widening', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Adjust mid/side width on desktop output. 100% leaves the file unchanged.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Width'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 2,
                    divisions: 40,
                    value: player.stereoWidth,
                    label: '${(player.stereoWidth * 100).round()}%',
                    onChanged: player.setStereoWidth,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${(player.stereoWidth * 100).round()}%',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputDeviceCard extends StatelessWidget {
  const _OutputDeviceCard({required this.devices, required this.onReload});

  final Future<List<OutputDeviceRow>>? devices;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Output device', style: text.titleMedium)),
                IconButton(
                  tooltip: 'Refresh devices',
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the desktop audio output. Android routing follows the system output.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            if (devices == null)
              const LinearProgressIndicator()
            else
              FutureBuilder<List<OutputDeviceRow>>(
                future: devices,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Could not list devices: ${snapshot.error}',
                          ),
                        ),
                        TextButton(
                          onPressed: onReload,
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  final rows = snapshot.data ?? const <OutputDeviceRow>[];
                  final selected =
                      rows.any((d) => d.id == player.outputDeviceId)
                      ? player.outputDeviceId
                      : 'default';
                  return DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Audio output',
                    ),
                    items: [
                      for (final d in rows)
                        DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(
                            d.isDefault ? '${d.name} (default)' : d.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) player.setOutputDevice(id);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplayGainCard extends StatelessWidget {
  const _ReplayGainCard({required this.rgOn});

  final bool rgOn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ReplayGain', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Even out perceived loudness between tracks using gain tags.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ReplayGainMode>(
              segments: const [
                ButtonSegment(value: ReplayGainMode.off, label: Text('Off')),
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
              onSelectionChanged: (s) => player.setReplayGainMode(s.first),
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
                    label: '${player.replayGainPreampDb.toStringAsFixed(1)} dB',
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
    );
  }
}

class _EqualizerCard extends StatelessWidget {
  const _EqualizerCard({
    required this.customPresets,
    required this.onReloadPresets,
    required this.onSavePreset,
    required this.onDeletePreset,
  });

  final Future<List<EqPresetRow>> customPresets;
  final VoidCallback onReloadPresets;
  final Future<void> Function() onSavePreset;
  final Future<void> Function(EqPresetRow preset) onDeletePreset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('10-band equalizer', style: text.titleMedium),
                ),
                Switch(value: player.eqEnabled, onChanged: player.setEqEnabled),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Desktop playback applies EQ live. Android EQ uses the same saved settings and will be active with the Android audio-effects pass.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _builtInPresets)
                  ActionChip(
                    label: Text(preset.name),
                    onPressed: () =>
                        player.setEqPreset(preset.gains, preset.preamp),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.save, size: 18),
                  label: const Text('Save custom'),
                  onPressed: onSavePreset,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<EqPresetRow>>(
              future: customPresets,
              builder: (context, snapshot) {
                final presets = snapshot.data ?? const <EqPresetRow>[];
                if (presets.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in presets)
                      InputChip(
                        label: Text(preset.name),
                        onPressed: () => player.setEqPreset(
                          preset.bands.toList(),
                          preset.preamp,
                        ),
                        onDeleted: preset.builtin
                            ? null
                            : () => onDeletePreset(preset),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _eqBands.length; i++)
              Row(
                children: [
                  SizedBox(width: 42, child: Text(_eqBands[i])),
                  Expanded(
                    child: Slider(
                      min: -12,
                      max: 12,
                      divisions: 48,
                      value: player.eqGains[i],
                      label: '${player.eqGains[i].toStringAsFixed(1)} dB',
                      onChanged: player.eqEnabled
                          ? (v) => player.setEqBand(i, v)
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${player.eqGains[i].toStringAsFixed(1)} dB',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                const SizedBox(width: 42, child: Text('Pre')),
                Expanded(
                  child: Slider(
                    min: -15,
                    max: 15,
                    divisions: 60,
                    value: player.eqPreampDb,
                    label: '${player.eqPreampDb.toStringAsFixed(1)} dB',
                    onChanged: player.eqEnabled ? player.setEqPreamp : null,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${player.eqPreampDb.toStringAsFixed(1)} dB',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: player.resetEq,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
