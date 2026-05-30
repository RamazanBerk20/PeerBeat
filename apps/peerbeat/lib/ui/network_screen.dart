import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../src/rust/api/network.dart';
import '../src/rust/db/tracks.dart';
import '../src/rust/net/discovery.dart';
import 'library_home.dart' show TrackListView;
import 'mini_player.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Network')),
      bottomNavigationBar: const MiniPlayer(),
      body: const NetworkPanel(),
    );
  }
}

class NetworkPanel extends StatefulWidget {
  const NetworkPanel({super.key});

  @override
  State<NetworkPanel> createState() => _NetworkPanelState();
}

class _NetworkPanelState extends State<NetworkPanel> {
  bool _hosting = false;
  int? _port;
  bool _discovering = false;
  List<HostInfo> _hosts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncHostState();
    _discover();
  }

  Future<void> _syncHostState() async {
    final h = await netIsHosting();
    final p = await netHostPort();
    if (mounted) {
      setState(() {
        _hosting = h;
        _port = p;
      });
    }
  }

  Future<void> _toggleHost(bool on) async {
    try {
      if (on) {
        final port = await netStartHost(
          dbPath: appDbPath,
          displayName: appDisplayName,
        );
        if (mounted) {
          setState(() {
            _hosting = true;
            _port = port;
          });
        }
      } else {
        await netStopHost();
        if (mounted) {
          setState(() {
            _hosting = false;
            _port = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    try {
      final hosts = await netDiscover(timeoutMs: 2500);
      if (mounted) setState(() => _hosts = hosts);
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _openHost(HostInfo h) async {
    final base = 'http://${h.address}:${h.port}';
    final client = HttpClient();
    try {
      final resp = await (await client.getUrl(
        Uri.parse('$base/v1/tracks'),
      )).close();
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw Exception('unexpected response from host');
      }
      final tracks = <TrackRow>[
        for (final raw in decoded)
          if (raw is Map<String, dynamic>)
            TrackRow(
              id: (raw['id'] as num?)?.toInt() ?? 0,
              title: (raw['title'] as String?) ?? '',
              artist: (raw['artist'] as String?) ?? '',
              album: (raw['album'] as String?) ?? '',
              albumId: null,
              durationMs: (raw['duration_ms'] as num?)?.toInt() ?? 0,
              year: null,
              rating: 0,
              playedCount: 0,
              path: '$base/v1/stream/${raw['id']}',
            ),
      ];
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(h.name)),
            body: TrackListView(tracks: tracks),
            bottomNavigationBar: const MiniPlayer(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reach ${h.name}: $e')),
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      children: [
        // LAN-only banner
        Container(
          width: double.infinity,
          color: cs.secondaryContainer,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local network only — nothing leaves your Wi-Fi. No cloud, no accounts.',
                  style: TextStyle(color: cs.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi_tethering),
          title: const Text('Share my library'),
          subtitle: Text(
            _hosting
                ? 'Sharing on port ${_port ?? '…'} as "$appDisplayName"'
                : 'Off',
          ),
          value: _hosting,
          onChanged: _toggleHost,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        const Divider(),
        ListTile(
          title: const Text('Discovered hosts'),
          trailing: _discovering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _discover,
                ),
        ),
        if (_hosts.isEmpty && !_discovering)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No hosts found on the network')),
          ),
        for (final h in _hosts)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.computer)),
            title: Text(h.name),
            subtitle: Text('${h.address}:${h.port}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openHost(h),
          ),
      ],
    );
  }
}
