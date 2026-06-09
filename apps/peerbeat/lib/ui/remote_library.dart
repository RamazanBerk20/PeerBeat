import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../net/party.dart';
import '../net/tofu.dart';
import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/tracks.dart';
import 'library_home.dart' show TrackArt, fmtDuration;
import 'mini_player.dart';

/// Browses a remote host's shared tracks: tap to stream, and — when the share
/// grants it — download a copy into the local library. Stream/download URLs
/// carry the scoped `?token=`; downloads go through the TOFU-pinned client.
class RemoteLibraryView extends StatefulWidget {
  const RemoteLibraryView({
    super.key,
    required this.title,
    required this.tracks,
    required this.base,
    required this.token,
    required this.canDownload,
  });

  final String title;
  final List<TrackRow> tracks;
  final String base;
  final String token;
  final bool canDownload;

  @override
  State<RemoteLibraryView> createState() => _RemoteLibraryViewState();
}

class _RemoteLibraryViewState extends State<RemoteLibraryView> {
  final _downloading = <int>{};
  bool _bulkBusy = false; // "Download all" in progress
  int _bulkDone = 0;
  int _bulkFailed = 0;

  /// Fetch one track's file into [dir]. Throws on HTTP error. No UI side
  /// effects, no client lifecycle — shared by single + bulk download.
  Future<void> _fetchTrack(HttpClient client, TrackRow t, Directory dir) async {
    final url =
        '${widget.base}/v1/tracks/${t.id}/download?token=${widget.token}';
    final resp = await (await client.getUrl(Uri.parse(url))).close();
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final file = File('${dir.path}/${_fileName(resp, t)}');
    final part = File('${file.path}.part');
    await resp.pipe(part.openWrite());
    await part.rename(file.path); // atomic publish
  }

  Future<void> _download(TrackRow t) async {
    setState(() => _downloading.add(t.id));
    final client = await tofuStreamClient();
    try {
      final dir = await _downloadsDir();
      await _fetchTrack(client, t, dir);
      await libraryScan(path: dir.path); // register + import the new file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded "${t.title}" to your library')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      client.close();
      if (mounted) setState(() => _downloading.remove(t.id));
    }
  }

  /// Download every shared track into the local library. Sequential and
  /// error-tolerant: a failed track is counted and skipped, not fatal. One
  /// library scan at the end registers everything in bulk. (No server zip
  /// endpoint exists yet, so this loops the per-track download.)
  Future<void> _downloadAll() async {
    if (_bulkBusy) return;
    setState(() {
      _bulkBusy = true;
      _bulkDone = 0;
      _bulkFailed = 0;
    });
    final client = await tofuStreamClient();
    try {
      final dir = await _downloadsDir();
      for (final t in widget.tracks) {
        if (!mounted) return;
        try {
          await _fetchTrack(client, t, dir);
          if (mounted) setState(() => _bulkDone++);
        } catch (_) {
          if (mounted) setState(() => _bulkFailed++);
        }
      }
      await libraryScan(path: dir.path); // bulk-register all new files at once
      if (mounted) {
        final failed = _bulkFailed > 0 ? ' ($_bulkFailed failed)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded $_bulkDone of ${widget.tracks.length} tracks'
              '$failed to your library',
            ),
          ),
        );
      }
    } finally {
      client.close();
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/PeerBeat');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileName(HttpClientResponse resp, TrackRow t) {
    // Prefer the server's Content-Disposition filename (keeps the codec ext so
    // the scanner can decode it); otherwise fall back to "artist - title".
    final cd = resp.headers.value('content-disposition');
    if (cd != null) {
      final m = RegExp('filename="?([^"]+)"?').firstMatch(cd);
      final fn = m?.group(1)?.trim();
      if (fn != null && fn.isNotEmpty) return _sanitize(fn);
    }
    final safe = _sanitize('${t.artist} - ${t.title}');
    return safe.isEmpty ? 'track_${t.id}' : safe;
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<void> _joinParty() async {
    try {
      await party.joinParty(widget.base, widget.token, widget.title);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined party — following the host')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not join party: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.canDownload)
            _bulkBusy
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Center(
                          child: Text('$_bulkDone/${widget.tracks.length}'),
                        ),
                      ],
                    ),
                  )
                : IconButton(
                    tooltip: 'Download all to my library',
                    icon: const Icon(Icons.download_for_offline_outlined),
                    onPressed: widget.tracks.isEmpty ? null : _downloadAll,
                  ),
          ListenableBuilder(
            listenable: party,
            builder: (context, _) => party.joined
                ? IconButton(
                    tooltip: 'Leave party',
                    icon: const Icon(Icons.exit_to_app),
                    onPressed: () => party.leaveParty(),
                  )
                : IconButton(
                    tooltip: 'Join party (sync to host)',
                    icon: const Icon(Icons.celebration_outlined),
                    onPressed: _joinParty,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: widget.tracks.isEmpty
          ? const Center(child: Text('Nothing shared here'))
          : ListenableBuilder(
              listenable: player,
              builder: (context, _) => ListView.builder(
                itemCount: widget.tracks.length,
                itemBuilder: (_, i) {
                  final t = widget.tracks[i];
                  final selected = player.current?.id == t.id;
                  final busy = _downloading.contains(t.id);
                  return ListTile(
                    selected: selected,
                    leading: TrackArt(track: t, selected: selected),
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (t.artist.isNotEmpty) t.artist,
                        if (t.album.isNotEmpty) t.album,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fmtDuration(t.durationMs)),
                        if (widget.canDownload)
                          busy
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Download to my library',
                                  icon: const Icon(Icons.download_outlined),
                                  onPressed: () => _download(t),
                                ),
                      ],
                    ),
                    onTap: () async {
                      try {
                        await player.playQueue(widget.tracks, i);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playback failed: $e')),
                          );
                        }
                      }
                    },
                    // In a party, long-press asks the host to play this track.
                    onLongPress: () {
                      if (party.joined) {
                        party.requestTrack(t.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Requested "${t.title}"')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Join the party to request tracks'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}
