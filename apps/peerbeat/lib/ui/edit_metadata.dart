import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/tracks.dart';

/// Loads the track's current tags, shows an editor, writes changes back to the
/// file, and returns the refreshed [TrackRow] (or `null` if cancelled/failed).
Future<TrackRow?> showEditMetadataDialog(
  BuildContext context,
  TrackRow track,
) async {
  TrackTags tags;
  try {
    tags = await libraryTrackTags(trackId: track.id);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotReadTags(e)),
        ),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<TrackRow>(
    context: context,
    builder: (_) => _EditMetadataDialog(track: track, tags: tags),
  );
}

/// Batch tag editor: apply a chosen field (album, album artist, genre, year, or
/// artist) across [trackIds], leaving every other field per-track. Returns the
/// updated rows (so the caller can refresh in place), or null if cancelled.
Future<List<TrackRow>?> showBatchEditDialog(
  BuildContext context,
  List<int> trackIds,
) {
  return showDialog<List<TrackRow>>(
    context: context,
    builder: (_) => _BatchEditDialog(trackIds: trackIds),
  );
}

class _BatchEditDialog extends StatefulWidget {
  const _BatchEditDialog({required this.trackIds});
  final List<int> trackIds;

  @override
  State<_BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<_BatchEditDialog> {
  final _album = TextEditingController();
  final _albumArtist = TextEditingController();
  final _genre = TextEditingController();
  final _artist = TextEditingController();
  final _year = TextEditingController();
  bool _doAlbum = false,
      _doAlbumArtist = false,
      _doGenre = false,
      _doArtist = false,
      _doYear = false;
  bool _saving = false;
  int _done = 0;

  @override
  void dispose() {
    for (final c in [_album, _albumArtist, _genre, _artist, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _anyField =>
      _doAlbum || _doAlbumArtist || _doGenre || _doArtist || _doYear;

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _done = 0;
    });
    final updated = <TrackRow>[];
    var failed = 0;
    for (final id in widget.trackIds) {
      try {
        final cur = await libraryTrackTags(trackId: id);
        final row = await libraryUpdateTags(
          trackId: id,
          title: cur.title,
          artist: _doArtist ? _artist.text : cur.artist,
          album: _doAlbum ? _album.text : cur.album,
          albumArtist: _doAlbumArtist ? _albumArtist.text : cur.albumArtist,
          genre: _doGenre ? _genre.text : cur.genre,
          year: _doYear ? int.tryParse(_year.text.trim()) : cur.year,
          trackNo: cur.trackNo,
        );
        updated.add(row);
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _done++);
    }
    if (!mounted) return;
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tracksNotUpdated(failed)),
        ),
      );
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(
      String label,
      bool on,
      ValueChanged<bool> toggle,
      TextEditingController c, {
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(value: on, onChanged: (v) => toggle(v ?? false)),
          Expanded(
            child: TextField(
              controller: c,
              enabled: on,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );

    final n = widget.trackIds.length;
    return AlertDialog(
      title: Text(l10n.editNTracks(n)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.batchEditHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              row(
                l10n.fieldAlbum,
                _doAlbum,
                (v) => setState(() => _doAlbum = v),
                _album,
              ),
              row(
                l10n.fieldAlbumArtist,
                _doAlbumArtist,
                (v) => setState(() => _doAlbumArtist = v),
                _albumArtist,
              ),
              row(
                l10n.fieldGenre,
                _doGenre,
                (v) => setState(() => _doGenre = v),
                _genre,
              ),
              row(
                l10n.fieldArtist,
                _doArtist,
                (v) => setState(() => _doArtist = v),
                _artist,
              ),
              row(
                l10n.fieldYear,
                _doYear,
                (v) => setState(() => _doYear = v),
                _year,
                number: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: (_saving || !_anyField) ? null : _apply,
          child: _saving ? Text('$_done/$n') : Text(l10n.commonApply),
        ),
      ],
    );
  }
}

class _EditMetadataDialog extends StatefulWidget {
  const _EditMetadataDialog({required this.track, required this.tags});
  final TrackRow track;
  final TrackTags tags;

  @override
  State<_EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<_EditMetadataDialog> {
  late final _title = TextEditingController(text: widget.tags.title);
  late final _artist = TextEditingController(text: widget.tags.artist);
  late final _album = TextEditingController(text: widget.tags.album);
  late final _albumArtist = TextEditingController(
    text: widget.tags.albumArtist,
  );
  late final _genre = TextEditingController(text: widget.tags.genre);
  late final _year = TextEditingController(
    text: widget.tags.year?.toString() ?? '',
  );
  late final _trackNo = TextEditingController(
    text: widget.tags.trackNo?.toString() ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _artist,
      _album,
      _albumArtist,
      _genre,
      _year,
      _trackNo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await libraryUpdateTags(
        trackId: widget.track.id,
        title: _title.text,
        artist: _artist.text,
        album: _album.text,
        albumArtist: _albumArtist.text,
        genre: _genre.text,
        year: int.tryParse(_year.text.trim()),
        trackNo: int.tryParse(_trackNo.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(
      String label,
      TextEditingController c, {
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );

    return AlertDialog(
      title: Text(l10n.editMetadata),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(l10n.fieldTitle, _title),
              field(l10n.fieldArtist, _artist),
              field(l10n.fieldAlbum, _album),
              field(l10n.fieldAlbumArtist, _albumArtist),
              field(l10n.fieldGenre, _genre),
              Row(
                children: [
                  Expanded(child: field(l10n.fieldYear, _year, number: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(l10n.fieldTrackNo, _trackNo, number: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
