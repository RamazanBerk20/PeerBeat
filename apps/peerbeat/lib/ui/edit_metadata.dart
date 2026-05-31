import 'package:flutter/material.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read tags: $e')));
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<TrackRow>(
    context: context,
    builder: (_) => _EditMetadataDialog(track: track, tags: tags),
  );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      title: const Text('Edit metadata'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('Title', _title),
              field('Artist (";"-separated)', _artist),
              field('Album', _album),
              field('Album artist', _albumArtist),
              field('Genre (";"-separated)', _genre),
              Row(
                children: [
                  Expanded(child: field('Year', _year, number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: field('Track #', _trackNo, number: true)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
