import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../playback/player.dart';
import '../update/updater.dart';
import '../src/rust/api/audio.dart' show OutputDeviceRow;
import '../src/rust/api/library.dart';
import '../src/rust/db/eq_presets.dart';
import 'text_input_dialog.dart';
import 'theme.dart' show kDefaultSeed;
import 'update_sheet.dart' show runUpdateFlow;

/// Fixed accent choices offered in Settings → Appearance (null = the default).
const _accentPresets = <Color>[
  Color(0xFF7C4DFF), // violet
  Color(0xFF42A5F5), // blue
  Color(0xFF26A69A), // teal-green
  Color(0xFF66BB6A), // green
  Color(0xFFFFB300), // amber
  Color(0xFFFF7043), // deep orange
  Color(0xFFEC407A), // pink
  Color(0xFFEF5350), // red
];

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
    final l10n = AppLocalizations.of(context);
    final name = await promptText(
      context,
      title: l10n.saveEqPreset,
      label: l10n.presetName,
      confirmLabel: l10n.commonSave,
    );
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) return;
    try {
      await eqPresetCreate(
        name: clean,
        bands: player.eqGains,
        preamp: player.eqPreampDb,
      );
      if (mounted) _reloadPresets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotSavePreset(e)),
        ),
      );
    }
  }

  Future<void> _deletePreset(EqPresetRow preset) async {
    try {
      await eqPresetDelete(presetId: preset.id);
      if (mounted) _reloadPresets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotDeletePreset(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final rgOn = player.replayGainMode != ReplayGainMode.off;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.settingsAudio, style: text.titleLarge),
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
            const SizedBox(height: 12),
            const _CrossfadeCard(),
            const SizedBox(height: 16),
            Text(l10n.settingsAppearance, style: text.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_6_outlined),
                    const SizedBox(width: 16),
                    Expanded(child: Text(l10n.settingsTheme)),
                    SegmentedButton<AppThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: AppThemeMode.system,
                          icon: const Icon(Icons.brightness_auto),
                          tooltip: l10n.themeSystem,
                        ),
                        ButtonSegment(
                          value: AppThemeMode.light,
                          icon: const Icon(Icons.light_mode),
                          tooltip: l10n.themeLight,
                        ),
                        ButtonSegment(
                          value: AppThemeMode.dark,
                          icon: const Icon(Icons.dark_mode),
                          tooltip: l10n.themeDark,
                        ),
                      ],
                      selected: {player.themeMode.value},
                      onSelectionChanged: (s) => player.setThemeMode(s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _LanguageCard(),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: Text(l10n.dynamicTheme),
                subtitle: Text(l10n.dynamicThemeSubtitle),
                value: player.dynamicTheme,
                onChanged: player.setDynamicTheme,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.color_lens_outlined),
                        const SizedBox(width: 16),
                        Expanded(child: Text(l10n.accentColor)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.dynamicTheme
                          ? l10n.accentDynamicHint
                          : l10n.accentPickHint,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _AccentSwatch(
                          color: null,
                          selected: player.accentSeed.value == null,
                          onTap: () => player.setAccentSeed(null),
                        ),
                        for (final c in _accentPresets)
                          _AccentSwatch(
                            color: c,
                            selected:
                                player.accentSeed.value?.toARGB32() ==
                                c.toARGB32(),
                            onTap: () => player.setAccentSeed(c),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.settingsAbout, style: text.titleLarge),
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('PeerBeat'),
                subtitle: Text(l10n.appTagline),
              ),
            ),
            const SizedBox(height: 8),
            const _UpdateCard(),
          ],
        );
      },
    );
  }
}

/// Version line + update controls. On Windows/Android the app self-updates from
/// GitHub Releases; on Linux updates are owned by the package manager.
class _UpdateCard extends StatefulWidget {
  const _UpdateCard();

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  String _version = '';
  bool _autoCheck = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await updater.currentVersion();
    final auto = await updater.autoCheckEnabled();
    if (mounted) {
      setState(() {
        _version = v;
        _autoCheck = auto;
      });
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final info = await updater.check();
      if (!mounted) return;
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).onLatestVersion)),
        );
      } else {
        await runUpdateFlow(context, info);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).updateCheckFailed(e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final managed = !updater.supported;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: Text(_version.isEmpty ? '…' : _version),
          ),
          if (managed)
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(l10n.updates),
              subtitle: Text(l10n.updatesManaged),
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.update_outlined),
              title: Text(l10n.checkAutomatically),
              value: _autoCheck,
              onChanged: (v) async {
                await updater.setAutoCheck(v);
                if (mounted) setState(() => _autoCheck = v);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l10n.checkForUpdates),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Language picker — System default + the ten supported locales, each shown in
/// its own script. Persists the choice via the player and re-renders live.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  // Native display names keyed by language code; null = follow the system.
  static const _names = <String?, String>{
    null: '',
    'en': 'English',
    'tr': 'Türkçe',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'ru': 'Русский',
    'ar': 'العربية',
    'ja': '日本語',
    'zh': '中文',
    'ko': '한국어',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<Locale?>(
      valueListenable: player.locale,
      builder: (context, current, _) {
        final code = current?.languageCode;
        final label = code == null
            ? l10n.languageSystemDefault
            : (_names[code] ?? code);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: Text(l10n.language),
            subtitle: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pick(context),
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final current = player.locale.value?.languageCode ?? '';
        return RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: SimpleDialog(
            title: Text(l10n.language),
            children: [
              for (final entry in _names.entries)
                RadioListTile<String>(
                  value: entry.key ?? '',
                  title: Text(
                    entry.key == null
                        ? l10n.languageSystemDefault
                        : entry.value,
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return; // dismissed
    player.setLocale(selected.isEmpty ? null : Locale(selected));
  }
}

class _StereoWidthCard extends StatelessWidget {
  const _StereoWidthCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.stereoWidening, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.stereoWideningHint, style: text.bodySmall),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: player,
              builder: (context, _) => Row(
                children: [
                  Text(l10n.width),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossfadeCard extends StatelessWidget {
  const _CrossfadeCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.crossfade, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.crossfadeHint, style: text.bodySmall),
            const SizedBox(height: 12),
            // Own ListenableBuilder so the controlled Slider follows the live
            // value even though this card itself is const (and so not rebuilt).
            ListenableBuilder(
              listenable: player,
              builder: (context, _) {
                final secs = player.crossfade;
                String fmt(double s) =>
                    s < 0.5 ? l10n.replayGainOff : '${s.toStringAsFixed(1)} s';
                return Row(
                  children: [
                    Text(l10n.duration),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 12,
                        divisions: 24,
                        value: secs.clamp(0.0, 12.0),
                        label: fmt(secs),
                        onChanged: player.setCrossfade,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(fmt(secs), textAlign: TextAlign.end),
                    ),
                  ],
                );
              },
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
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.outputDevice, style: text.titleMedium),
                ),
                IconButton(
                  tooltip: l10n.refreshDevices,
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.outputDeviceHint, style: text.bodySmall),
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
                            l10n.couldNotListDevices(snapshot.error ?? ''),
                          ),
                        ),
                        TextButton(
                          onPressed: onReload,
                          child: Text(l10n.commonRetry),
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
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: l10n.audioOutput,
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
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.replayGain, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.replayGainHint, style: text.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<ReplayGainMode>(
              segments: [
                ButtonSegment(
                  value: ReplayGainMode.off,
                  label: Text(l10n.replayGainOff),
                ),
                ButtonSegment(
                  value: ReplayGainMode.track,
                  label: Text(l10n.replayGainTrack),
                ),
                ButtonSegment(
                  value: ReplayGainMode.album,
                  label: Text(l10n.replayGainAlbum),
                ),
              ],
              selected: {player.replayGainMode},
              onSelectionChanged: (s) => player.setReplayGainMode(s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(l10n.preamp),
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
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.equalizer10Band, style: text.titleMedium),
                ),
                Switch(value: player.eqEnabled, onChanged: player.setEqEnabled),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.equalizerHint, style: text.bodySmall),
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
                  label: Text(l10n.saveCustom),
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
            // Graphic EQ: a row of vertical band sliders (drag up/down to boost
            // or cut), forming the familiar response-curve shape.
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  for (var i = 0; i < _eqBands.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 18,
                            child: Text(
                              player.eqGains[i].toStringAsFixed(0),
                              style: text.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                min: -12,
                                max: 12,
                                divisions: 48,
                                value: player.eqGains[i],
                                onChanged: player.eqEnabled
                                    ? (v) => player.setEqBand(i, v)
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 18,
                            child: Text(_eqBands[i], style: text.labelSmall),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                SizedBox(width: 42, child: Text(l10n.eqPre)),
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
                label: Text(l10n.commonReset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular accent swatch for the Appearance accent picker. `color == null`
/// means "the built-in default". 48 dp hit target for accessibility.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final swatch = color ?? kDefaultSeed;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: color == null ? l10n.accentDefault : l10n.accentColor,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.onSurface : cs.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Icon(
                color == null
                    ? Icons.auto_awesome
                    : (selected ? Icons.check : null),
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
