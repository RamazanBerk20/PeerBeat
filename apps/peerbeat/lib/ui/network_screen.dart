import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../net/tofu.dart';
import '../src/rust/api/network.dart';
import '../src/rust/db/tracks.dart';
import '../src/rust/net/discovery.dart';
import 'library_home.dart' show TrackListView;
import 'mini_player.dart';
import 'sharing_screen.dart';

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

  /// Browse a host: fetch its shared scopes, let the user pick one (entering a
  /// PIN if required), authenticate for a scoped token, then list + open its
  /// tracks. Streaming carries the token as a `?token=` query param.
  Future<void> _openHost(HostInfo h) async {
    final base = 'https://${h.address}:${h.port}';
    final key = h.hostId.isEmpty ? '${h.address}:${h.port}' : h.hostId;
    final tc = await TofuHostClient.forHost(key, h.name);
    try {
      // 1. Public list of shareable scopes.
      final resp = await (await tc.client.getUrl(
        Uri.parse('$base/v1/shares'),
      )).close();
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw Exception('unexpected response from host');
      }
      // Pin the cert only after the response validates as a genuine PeerBeat
      // reply — a first-use MITM returning 200 + garbage must not lock in a cert.
      await tc.confirmPin();
      final shares = [
        for (final raw in decoded)
          if (raw is Map<String, dynamic>) _ShareDesc.fromJson(raw),
      ];
      if (!mounted) return;
      if (shares.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${h.name} isn't sharing anything right now")),
        );
        return;
      }

      // 2. Let the user choose a scope.
      final chosen = await showModalBottomSheet<_ShareDesc>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                title: Text('Shared by ${h.name}'),
              ),
              for (final s in shares)
                ListTile(
                  leading: Icon(
                    s.scope == 'library'
                        ? Icons.library_music
                        : Icons.queue_music,
                  ),
                  title: Text(s.label),
                  subtitle: Text(
                    '${s.requiresPin ? 'PIN · ' : ''}'
                    '${s.permission == 'stream_download' ? 'stream + download' : 'stream only'}',
                  ),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      );
      if (chosen == null || !mounted) return;

      // 3. PIN prompt if needed.
      String? pin;
      if (chosen.requiresPin) {
        pin = await _promptPin();
        if (pin == null || !mounted) return;
      }

      // 4. Authenticate for a scoped token.
      final token = await _authenticate(tc, base, chosen, pin);
      if (token == null || !mounted) return;

      // 5. List the tracks in scope.
      final listPath = chosen.scope == 'library'
          ? '/v1/tracks'
          : '/v1/playlists/${chosen.playlistId}';
      final treq = await tc.client.getUrl(Uri.parse('$base$listPath'));
      treq.headers.add('authorization', 'Bearer $token');
      final tresp = await treq.close();
      if (tresp.statusCode != 200) {
        throw Exception('HTTP ${tresp.statusCode}');
      }
      final tdecoded = jsonDecode(await tresp.transform(utf8.decoder).join());
      if (tdecoded is! List) {
        throw Exception('unexpected track list');
      }
      final tracks = <TrackRow>[
        for (final raw in tdecoded)
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
              path: '$base/v1/stream/${raw['id']}?token=$token',
            ),
      ];
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('${h.name} · ${chosen.label}')),
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
      tc.close();
    }
  }

  /// POST /v1/auth/session for a scoped bearer token. Returns null (with a
  /// snackbar) on a rejected PIN / denied access.
  Future<String?> _authenticate(
    TofuHostClient tc,
    String base,
    _ShareDesc share,
    String? pin,
  ) async {
    final req = await tc.client.postUrl(Uri.parse('$base/v1/auth/session'));
    req.headers.set('content-type', 'application/json');
    final payload = <String, dynamic>{'scope': share.scope};
    if (share.playlistId != null) payload['playlist_id'] = share.playlistId;
    if (pin != null) payload['pin'] = pin;
    req.write(jsonEncode(payload));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resp.statusCode == 401
                  ? 'Incorrect PIN'
                  : 'Access denied: ${body.trim()}',
            ),
          ),
        );
      }
      return null;
    }
    final decoded = jsonDecode(body);
    return (decoded is Map && decoded['token'] is String)
        ? decoded['token'] as String
        : null;
  }

  Future<String?> _promptPin() async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enter PIN'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '4–6 digits'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
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
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('Manage what I share'),
          subtitle: const Text(
            'Playlists or the whole library, with access mode & PIN',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SharingScreen()),
          ),
        ),
        if (_hosting)
          ListTile(
            leading: Icon(Icons.block, color: cs.error),
            title: const Text('Revoke all peer access'),
            subtitle: const Text(
              'Disconnect everyone; they must re-authenticate',
            ),
            onTap: () async {
              await netRevokeAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All peer sessions revoked')),
                );
              }
            },
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

/// One shareable scope advertised by a host's `/v1/shares`.
class _ShareDesc {
  _ShareDesc({
    required this.scope,
    required this.playlistId,
    required this.label,
    required this.mode,
    required this.permission,
    required this.requiresPin,
  });

  final String scope; // "library" | "playlist"
  final int? playlistId;
  final String label;
  final String mode;
  final String permission;
  final bool requiresPin;

  factory _ShareDesc.fromJson(Map<String, dynamic> j) => _ShareDesc(
    scope: (j['scope'] as String?) ?? 'library',
    playlistId: (j['playlist_id'] as num?)?.toInt(),
    label: (j['label'] as String?) ?? 'Shared',
    mode: (j['mode'] as String?) ?? 'open',
    permission: (j['permission'] as String?) ?? 'stream',
    requiresPin: (j['requires_pin'] as bool?) ?? false,
  );
}
