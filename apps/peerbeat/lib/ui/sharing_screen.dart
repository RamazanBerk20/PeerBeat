import 'package:flutter/material.dart';

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

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sharing')),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pick what peers on your network can stream or download. '
                  'Changes apply immediately while you are sharing.',
                ),
              ),
              _ShareTile(
                label: 'Whole library',
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
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No playlists yet')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Sharing "${widget.label}"'
                : 'Stopped sharing "${widget.label}"',
          ),
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update sharing: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ? '${_modeLabel(_mode)} · ${_permLabel(_permission)}'
                : 'Not shared',
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
                    const Text('Access: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _mode,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _mode = v ?? 'open'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(value: 'pin', child: Text('PIN')),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved (soon)'),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Peers can: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _permission,
                      onChanged: _busy
                          ? null
                          : (v) =>
                                setState(() => _permission = v ?? 'stream'),
                      items: const [
                        DropdownMenuItem(
                          value: 'stream',
                          child: Text('Stream only'),
                        ),
                        DropdownMenuItem(
                          value: 'stream_download',
                          child: Text('Stream + download'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_mode == 'pin')
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: hasPin
                          ? 'Change PIN (leave blank to keep)'
                          : 'Set a 4–6 digit PIN',
                    ),
                  ),
                if (_mode == 'approved')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Approved-peer prompts arrive with the control channel; '
                      'peers cannot connect in this mode yet.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(enabled: true),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _modeLabel(String m) =>
    switch (m) { 'pin' => 'PIN', 'approved' => 'Approved', _ => 'Open' };

String _permLabel(String p) =>
    p == 'stream_download' ? 'stream + download' : 'stream only';
