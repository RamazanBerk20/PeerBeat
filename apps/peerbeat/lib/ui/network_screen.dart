import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_localizations.dart';
import '../net/party.dart';
import '../net/tofu.dart';
import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/api/network.dart';
import '../src/rust/db/tracks.dart';
import '../src/rust/db/transfer_log.dart';
import '../src/rust/net/discovery.dart';
import 'mini_player.dart';
import 'remote_library.dart';
import 'sharing_screen.dart';
import 'text_input_dialog.dart';

/// A stable, distinct color for a host or peer, derived from its id/name — so
/// devices are visually recognizable across the discovery + connections lists.
Color hostColorFor(String key) {
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, 0.55).toColor();
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).networkTitle)),
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
          SnackBar(
            content: Text(AppLocalizations.of(context).hostNotSharing(h.name)),
          ),
        );
        return;
      }

      // 2. Let the user choose a scope.
      final l10n = AppLocalizations.of(context);
      final chosen = await showModalBottomSheet<_ShareDesc>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(dense: true, title: Text(l10n.sharedBy(h.name))),
              for (final s in shares)
                ListTile(
                  leading: Icon(
                    s.scope == 'library'
                        ? Icons.library_music
                        : Icons.queue_music,
                  ),
                  title: Text(s.label),
                  subtitle: Text(
                    '${s.requiresPin ? '${l10n.accessPin} · ' : ''}'
                    '${s.permission == 'stream_download' ? l10n.streamAndDownload : l10n.streamOnly}',
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
          builder: (_) => RemoteLibraryView(
            title: '${h.name} · ${chosen.label}',
            tracks: tracks,
            base: base,
            token: token,
            canDownload: chosen.permission == 'stream_download',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).couldNotReachHost(h.name, e),
            ),
          ),
        );
      }
    } finally {
      tc.close();
    }
  }

  /// POST /v1/auth/session for a scoped bearer token. Handles the approved-peers
  /// handshake (202 → poll until the host allows/denies). Returns null (with a
  /// snackbar) on a rejected PIN / denied access / cancel.
  Future<String?> _authenticate(
    TofuHostClient tc,
    String base,
    _ShareDesc share,
    String? pin,
  ) async {
    final (code, body) = await _postAuth(tc, base, share, pin, null);
    if (code == 200) return _tokenFrom(body);
    if (code == 202) {
      final challenge = _challengeFrom(body);
      if (challenge == null) return null;
      return _awaitApproval(tc, base, share, challenge);
    }
    _surfaceAuthError(code, body);
    return null;
  }

  /// One POST to /v1/auth/session; returns (statusCode, body). `challenge`
  /// is the approved-peers poll handle (null on the first request).
  Future<(int, String)> _postAuth(
    TofuHostClient tc,
    String base,
    _ShareDesc share,
    String? pin,
    String? challenge,
  ) async {
    final req = await tc.client.postUrl(Uri.parse('$base/v1/auth/session'));
    req.headers.set('content-type', 'application/json');
    final payload = <String, dynamic>{'scope': share.scope};
    if (share.playlistId != null) payload['playlist_id'] = share.playlistId;
    if (pin != null) payload['pin'] = pin;
    if (challenge != null) payload['challenge'] = challenge;
    req.write(jsonEncode(payload));
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    return (resp.statusCode, text);
  }

  String? _tokenFrom(String body) {
    final decoded = jsonDecode(body);
    return (decoded is Map && decoded['token'] is String)
        ? decoded['token'] as String
        : null;
  }

  String? _challengeFrom(String body) {
    final decoded = jsonDecode(body);
    return (decoded is Map && decoded['challenge'] is String)
        ? decoded['challenge'] as String
        : null;
  }

  void _surfaceAuthError(int code, String body) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          code == 401
              ? l10n.incorrectPin
              : code == 429
              ? l10n.tooManyAttempts
              : l10n.accessDenied(body.trim()),
        ),
      ),
    );
  }

  /// Poll the host while it decides on an approved-peers request. Shows a
  /// cancellable "waiting" dialog; resolves to a token (allowed) or null.
  Future<String?> _awaitApproval(
    TofuHostClient tc,
    String base,
    _ShareDesc share,
    String challenge,
  ) async {
    var cancelled = false;
    if (mounted) {
      // The dialog future completes when the host decides or the user cancels.
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(AppLocalizations.of(ctx).waitingForHost)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  Navigator.of(ctx).pop();
                },
                child: Text(AppLocalizations.of(ctx).commonCancel),
              ),
            ],
          ),
        ),
      );
    }
    String? token;
    // ~2 minutes of polling at 1.5s cadence.
    for (var i = 0; i < 80 && !cancelled; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (cancelled) break;
      final (code, body) = await _postAuth(tc, base, share, null, challenge);
      if (code == 200) {
        token = _tokenFrom(body);
        break;
      }
      if (code == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).hostDenied)),
          );
        }
        break;
      }
      // 202 → still pending; keep polling.
    }
    // Close the waiting dialog if it's still up.
    if (!cancelled && mounted) Navigator.of(context, rootNavigator: true).pop();
    return token;
  }

  Future<String?> _promptPin() {
    final l10n = AppLocalizations.of(context);
    return promptText(
      context,
      title: l10n.enterPin,
      hint: l10n.pinDigitsHint,
      keyboardType: TextInputType.number,
      confirmLabel: l10n.connect,
    );
  }

  /// Manual fallback for when mDNS discovery doesn't surface a host: the user
  /// types `ip:port` (the host shows its port on its "Share my library" tile).
  /// We build a synthetic [HostInfo] and run the normal open-host + TOFU flow.
  Future<void> _connectByIp() async {
    final l10n = AppLocalizations.of(context);
    final input = await promptText(
      context,
      title: l10n.connectByIp,
      hint: l10n.ipExampleHint,
      confirmLabel: l10n.connect,
    );
    if (input == null || !mounted) return;
    final raw = input.trim();
    final colon = raw.lastIndexOf(':');
    final addr = colon > 0 ? raw.substring(0, colon) : raw;
    final port = colon > 0 ? int.tryParse(raw.substring(colon + 1)) : null;
    if (addr.isEmpty || port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).enterAddressHint)),
      );
      return;
    }
    // If this address:port is already a discovered host, reuse its identity so
    // we pin under its stable host_id rather than creating a second TOFU trust
    // anchor (ip:port) for the same device.
    final matches = _hosts.where((h) => h.address == addr && h.port == port);
    final match = matches.isEmpty ? null : matches.first;
    await _openHost(
      match ??
          HostInfo(
            name: raw,
            address: addr,
            port: port,
            hostId: '',
            fingerprint: '',
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
                  l10n.lanOnlyBanner,
                  style: TextStyle(color: cs.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi_tethering),
          title: Text(l10n.shareMyLibrary),
          subtitle: Text(
            _hosting
                ? l10n.sharingOnPort('${_port ?? '…'}', appDisplayName)
                : l10n.off,
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
          title: Text(l10n.manageWhatIShare),
          subtitle: Text(l10n.manageWhatIShareSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SharingScreen())),
        ),
        if (_hosting)
          ListTile(
            leading: Icon(Icons.block, color: cs.error),
            title: Text(l10n.revokeAllPeerAccess),
            subtitle: Text(l10n.revokeAllSubtitle),
            onTap: () async {
              await netRevokeAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.allSessionsRevoked)),
                );
              }
            },
          ),
        if (_hosting)
          ListenableBuilder(
            listenable: party,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.celebration_outlined),
              title: Text(l10n.partyMode),
              subtitle: Text(
                party.hosting
                    ? l10n.partyModeOnSubtitle
                    : l10n.partyModeOffSubtitle,
              ),
              value: party.hosting,
              onChanged: (on) =>
                  on ? party.startHosting() : party.stopHosting(),
            ),
          ),
        if (_hosting) const _ApprovalsSection(),
        if (_hosting) const _PartyRequestsSection(),
        if (_hosting) const _ConnectionsSection(),
        const Divider(),
        ListTile(
          title: Text(l10n.discoveredHosts),
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
        ListTile(
          leading: const Icon(Icons.add_link),
          title: Text(l10n.connectByIpAddress),
          subtitle: Text(l10n.reachHostManually),
          onTap: _connectByIp,
        ),
        if (_hosts.isEmpty && !_discovering)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(l10n.noHostsFound)),
          ),
        for (final h in _hosts)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: hostColorFor(
                h.hostId.isEmpty ? '${h.address}:${h.port}' : h.hostId,
              ),
              child: Text(
                h.name.isNotEmpty ? h.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
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

/// Host dashboard: who currently has a session (with per-peer revoke) and a log
/// of recent streams/downloads. Shown only while hosting.
class _ConnectionsSection extends StatefulWidget {
  const _ConnectionsSection();

  @override
  State<_ConnectionsSection> createState() => _ConnectionsSectionState();
}

class _ConnectionsSectionState extends State<_ConnectionsSection> {
  List<String> _peers = const [];
  List<TransferRow> _activity = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final peers = await netActivePeers();
      final activity = await netRecentTransfers(limit: 25);
      if (mounted) {
        setState(() {
          _peers = peers;
          _activity = activity;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.connectionsAndActivity),
          trailing: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
        ),
        if (_peers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.noPeersConnected),
          )
        else
          for (final p in _peers)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: hostColorFor(p),
                child: const Icon(Icons.person, size: 16, color: Colors.white),
              ),
              title: Text(p),
              subtitle: Text(l10n.activeSession),
              trailing: TextButton(
                onPressed: () async {
                  await netRevokePeer(peer: p);
                  await _refresh();
                },
                child: Text(l10n.revoke),
              ),
            ),
        if (_activity.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.recentActivity,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final a in _activity)
            ListTile(
              dense: true,
              leading: Icon(
                a.kind == 'download' ? Icons.download : Icons.play_arrow,
                size: 18,
              ),
              title: Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${a.peer} • ${a.kind}'),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await netClearActivity();
                await _refresh();
              },
              child: Text(l10n.clearActivity),
            ),
          ),
        ],
      ],
    );
  }
}

/// Host-side approval prompts for peers connecting under "approved peers" mode.
/// Polls the pending queue while hosting and offers Allow / Deny / Always.
class _ApprovalsSection extends StatefulWidget {
  const _ApprovalsSection();

  @override
  State<_ApprovalsSection> createState() => _ApprovalsSectionState();
}

class _ApprovalsSectionState extends State<_ApprovalsSection> {
  List<PendingApprovalDto> _pending = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final p = await netPendingApprovals();
      if (mounted) setState(() => _pending = p);
    } catch (_) {
      // best-effort poll
    }
  }

  Future<void> _decide(PendingApprovalDto p, bool allow, bool remember) async {
    await netDecidePeer(
      challenge: p.challenge,
      allow: allow,
      remember: remember,
    );
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allow ? l10n.peerAllowed(p.peer) : l10n.peerDenied(p.peer),
          ),
        ),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: cs.tertiaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.how_to_reg, color: cs.onTertiaryContainer),
              const SizedBox(width: 8),
              Text(
                l10n.approvalRequests,
                style: TextStyle(
                  color: cs.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        for (final p in _pending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.peerWantsToConnect(p.peer, p.label)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _decide(p, true, false),
                      child: Text(l10n.allowOnce),
                    ),
                    OutlinedButton(
                      onPressed: () => _decide(p, true, true),
                      child: Text(l10n.alwaysAllow),
                    ),
                    TextButton(
                      onPressed: () => _decide(p, false, false),
                      child: Text(l10n.deny),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Host-side list of party "play this" requests from peers. Polls + accumulates
/// (the Rust side drains on read), and lets the host play or dismiss each.
class _PartyRequestsSection extends StatefulWidget {
  const _PartyRequestsSection();

  @override
  State<_PartyRequestsSection> createState() => _PartyRequestsSectionState();
}

class _PartyRequestsSectionState extends State<_PartyRequestsSection> {
  final List<PartyRequestDto> _requests = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await netPartyRequests();
      if (fresh.isNotEmpty && mounted) {
        setState(() => _requests.addAll(fresh));
      }
    } catch (_) {
      // best-effort poll
    }
  }

  Future<void> _play(PartyRequestDto r) async {
    try {
      final t = await libraryTrackById(trackId: r.trackId);
      if (t != null) await player.playSingle(t);
    } catch (_) {
      // ignore: the track may have been removed
    }
    if (mounted) setState(() => _requests.remove(r));
  }

  @override
  Widget build(BuildContext context) {
    if (_requests.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: cs.secondaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.playlist_add_check, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                l10n.partyRequestsTitle,
                style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        for (final r in _requests)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: hostColorFor(r.peer),
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(l10n.requestedByPeer(r.peer)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: () => _play(r),
                  child: Text(l10n.commonPlay),
                ),
                IconButton(
                  tooltip: l10n.dismiss,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _requests.remove(r)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
