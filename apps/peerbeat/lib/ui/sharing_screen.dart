import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/playlists.dart';
import '../src/rust/db/shares.dart';
import 'mini_player.dart';

/// Host-side sharing config: choose which playlists (or the whole library) to
/// expose on the LAN, with an access mode (open / PIN / approved) and a
/// permission (stream / stream+download). Backed by the Rust `share_*` API.
class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key});

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  late Future<_SharingData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SharingData> _load() async {
    final shares = await shareList();
    final playlists = await playlistList();
    final byScope = <int?, ShareRow>{};
    for (final s in shares) {
      byScope[s.playlistId?.toInt()] = s;
    }
    return _SharingData(playlists: playlists, byScope: byScope);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharingTitle)),
      bottomNavigationBar: const MiniPlayer(),
      body: FutureBuilder<_SharingData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.sharingHint),
              ),
              _ShareTile(
                label: l10n.wholeLibrary,
                playlistId: null,
                existing: data.byScope[null],
                onChanged: _reload,
              ),
              const Divider(),
              for (final p in data.playlists)
                _ShareTile(
                  label: p.name,
                  playlistId: p.id.toInt(),
                  existing: data.byScope[p.id.toInt()],
                  onChanged: _reload,
                ),
              if (data.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.noPlaylistsYet)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SharingData {
  _SharingData({required this.playlists, required this.byScope});
  final List<PlaylistRow> playlists;
  final Map<int?, ShareRow> byScope;
}

class _ShareTile extends StatefulWidget {
  const _ShareTile({
    required this.label,
    required this.playlistId,
    required this.existing,
    required this.onChanged,
  });

  final String label;
  final int? playlistId;
  final ShareRow? existing;
  final VoidCallback onChanged;

  @override
  State<_ShareTile> createState() => _ShareTileState();
}

class _ShareTileState extends State<_ShareTile> {
  late bool _enabled;
  late String _mode; // open | pin | approved
  late String _permission; // stream | stream_download
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _enabled = e?.enabled ?? false;
    _mode = e?.mode ?? 'open';
    _permission = e?.permission ?? 'stream';
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save({required bool enabled}) async {
    final newPin = _pin.text.trim();
    final hasPin = widget.existing?.hasPin ?? false;
    // Validate a PIN share before hitting the network: a fresh PIN must be 4–6
    // digits, and a brand-new PIN share must actually set one.
    if (enabled && _mode == 'pin') {
      final needsPin = !hasPin && newPin.isEmpty;
      final badPin =
          newPin.isNotEmpty &&
          !(newPin.length >= 4 &&
              newPin.length <= 6 &&
              RegExp(r'^\d+$').hasMatch(newPin));
      if (needsPin || badPin) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(needsPin ? l10n.setPinFirst : l10n.pinMustBeDigits),
          ),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await shareSet(
        playlistId: widget.playlistId,
        permission: _permission,
        mode: _mode,
        pin: _pin.text.trim().isEmpty ? null : _pin.text.trim(),
        enabled: enabled,
      );
      _pin.clear();
      if (!mounted) return;
      setState(() => _enabled = enabled);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? l10n.sharingNamed(widget.label)
                : l10n.stoppedSharingNamed(widget.label),
          ),
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).couldNotUpdateSharing(e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPin = widget.existing?.hasPin ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          secondary: Icon(
            widget.playlistId == null ? Icons.library_music : Icons.queue_music,
          ),
          title: Text(widget.label),
          subtitle: Text(
            _enabled
                ? '${_modeLabel(l10n, _mode)} · ${_permLabel(l10n, _permission)}'
                : l10n.notShared,
          ),
          value: _enabled,
          onChanged: _busy ? null : (v) => _save(enabled: v),
        ),
        if (_enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l10n.accessLabel),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _mode,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _mode = v ?? 'open'),
                      items: [
                        DropdownMenuItem(
                          value: 'open',
                          child: Text(l10n.accessOpen),
                        ),
                        DropdownMenuItem(
                          value: 'pin',
                          child: Text(l10n.accessPin),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text(l10n.accessApproved),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(l10n.peersCanLabel),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _permission,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _permission = v ?? 'stream'),
                      items: [
                        DropdownMenuItem(
                          value: 'stream',
                          child: Text(l10n.streamOnly),
                        ),
                        DropdownMenuItem(
                          value: 'stream_download',
                          child: Text(l10n.streamAndDownload),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_mode == 'pin')
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: hasPin ? l10n.changePin : l10n.setPin,
                    ),
                  ),
                if (_mode == 'approved')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.approvedModeHint,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(enabled: true),
                    child: Text(l10n.commonApply),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _modeLabel(AppLocalizations l10n, String m) => switch (m) {
  'pin' => l10n.accessPin,
  'approved' => l10n.accessApproved,
  _ => l10n.accessOpen,
};

String _permLabel(AppLocalizations l10n, String p) =>
    p == 'stream_download' ? l10n.streamAndDownload : l10n.streamOnly;
