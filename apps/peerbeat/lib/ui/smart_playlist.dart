import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../playback/player.dart';
import '../src/rust/api/library.dart';
import '../src/rust/db/smart.dart';
import '../src/rust/db/tracks.dart';
import 'library_home.dart' show TrackListView;
import 'mini_player.dart';

/// Selectable rule fields → display label. Text fields use text operators,
/// numeric fields use comparison operators (mirrors the Rust whitelist).
const _fieldLabels = <String, String>{
  'title': 'Title',
  'artist': 'Artist',
  'album': 'Album',
  'genre': 'Genre',
  'year': 'Year',
  'rating': 'Rating',
  'played_count': 'Play count',
  'duration_ms': 'Duration (ms)',
  'added_at': 'Date added',
};
const _textFields = {'title', 'artist', 'album', 'genre'};

const _textOps = <String, String>{
  'contains': 'contains',
  'is': 'is',
  'isNot': 'is not',
  'startsWith': 'starts with',
  'endsWith': 'ends with',
  'notContains': "doesn't contain",
};
const _numOps = <String, String>{
  'eq': '=',
  'neq': '≠',
  'gt': '>',
  'lt': '<',
  'gte': '≥',
  'lte': '≤',
  'inLastDays': 'in last N days',
};

bool _isText(String field) => _textFields.contains(field);
Map<String, String> _opsFor(String field) =>
    _isText(field) ? _textOps : _numOps;

class _RuleRow {
  _RuleRow({this.field = 'artist', String? op, this.value = ''})
    : op = op ?? (_isText(field) ? 'contains' : 'gte');
  String field;
  String op;
  String value;
}

/// Create/edit a smart playlist (name + match mode + rule rows + optional cap).
/// Pops `true` if saved.
class SmartPlaylistEditor extends StatefulWidget {
  const SmartPlaylistEditor({super.key, this.existing});
  final SmartPlaylistRow? existing;

  @override
  State<SmartPlaylistEditor> createState() => _SmartPlaylistEditorState();
}

class _SmartPlaylistEditorState extends State<SmartPlaylistEditor> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  String _match = 'all';
  final List<_RuleRow> _rules = [];
  int? _previewCount;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _limit = TextEditingController(text: e?.limitN?.toString() ?? '');
    if (e != null) {
      try {
        final m = jsonDecode(e.ruleJson) as Map<String, dynamic>;
        _match = (m['match'] as String?) ?? 'all';
        for (final r in (m['rules'] as List? ?? const [])) {
          final map = r as Map<String, dynamic>;
          _rules.add(
            _RuleRow(
              field: map['field'] as String? ?? 'artist',
              op: map['op'] as String?,
              value: (map['value'] ?? '').toString(),
            ),
          );
        }
      } catch (_) {
        /* corrupt rule json — start empty */
      }
    }
    if (_rules.isEmpty) _rules.add(_RuleRow());
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  String _ruleJson() => jsonEncode({
    'match': _match,
    'rules': [
      for (final r in _rules) {'field': r.field, 'op': r.op, 'value': r.value},
    ],
  });

  int? get _limitValue {
    final n = int.tryParse(_limit.text.trim());
    return (n != null && n > 0) ? n : null;
  }

  Future<void> _preview() async {
    try {
      final rows = await smartPlaylistPreview(
        ruleJson: _ruleJson(),
        limitN: _limitValue,
      );
      if (mounted) setState(() => _previewCount = rows.length);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).invalidRules(e))),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).enterAName)),
      );
      return;
    }
    try {
      if (widget.existing == null) {
        await smartPlaylistCreate(
          name: name,
          ruleJson: _ruleJson(),
          limitN: _limitValue,
        );
      } else {
        await smartPlaylistUpdate(
          smartId: widget.existing!.id,
          name: name,
          ruleJson: _ruleJson(),
          limitN: _limitValue,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotSave(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.newSmartPlaylist
              : l10n.editSmartPlaylist,
        ),
        actions: [TextButton(onPressed: _save, child: Text(l10n.commonSave))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l10n.ruleMatch),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text(l10n.ruleMatchAll)),
                  ButtonSegment(value: 'any', label: Text(l10n.ruleMatchAny)),
                ],
                selected: {_match},
                onSelectionChanged: (s) => setState(() => _match = s.first),
              ),
              const SizedBox(width: 12),
              Text(l10n.ofTheseRules),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _rules.length; i++) _ruleRow(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rules.add(_RuleRow())),
              icon: const Icon(Icons.add),
              label: Text(l10n.addRule),
            ),
          ),
          const Divider(),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.limitOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _preview,
                icon: const Icon(Icons.search),
                label: Text(
                  _previewCount == null
                      ? l10n.preview
                      : l10n.matchesCount(_previewCount!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(int i) {
    final l10n = AppLocalizations.of(context);
    final r = _rules[i];
    final ops = _opsFor(r.field);
    final isText = _isText(r.field);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: r.field,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final e in _fieldLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  r.field = v;
                  final valid = _opsFor(v);
                  if (!valid.containsKey(r.op)) r.op = valid.keys.first;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: ops.containsKey(r.op) ? r.op : ops.keys.first,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final e in ops.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => r.op = v ?? r.op),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: r.value,
              keyboardType: isText ? TextInputType.text : TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.ruleValueHint,
              ),
              onChanged: (v) => r.value = v,
            ),
          ),
          IconButton(
            tooltip: l10n.removeRule,
            icon: const Icon(Icons.close),
            onPressed: _rules.length == 1
                ? null
                : () => setState(() => _rules.removeAt(i)),
          ),
        ],
      ),
    );
  }
}

/// Read-only view of a smart playlist's current matches, with play-all.
class SmartPlaylistDetail extends StatefulWidget {
  const SmartPlaylistDetail({super.key, required this.smart});
  final SmartPlaylistRow smart;

  @override
  State<SmartPlaylistDetail> createState() => _SmartPlaylistDetailState();
}

class _SmartPlaylistDetailState extends State<SmartPlaylistDetail> {
  late Future<List<TrackRow>> _future = smartPlaylistTracks(
    smartId: widget.smart.id,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.smart.name),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _future = smartPlaylistTracks(smartId: widget.smart.id);
            }),
          ),
        ],
      ),
      body: FutureBuilder<List<TrackRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snap.data!;
          if (tracks.isEmpty) {
            return Center(child: Text(l10n.noTracksMatchRules));
          }
          return TrackListView(tracks: tracks);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final tracks = await _future;
          if (tracks.isNotEmpty) await player.playQueue(tracks, 0);
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.playAll),
      ),
      // Keep the persistent mini-player on this route too — otherwise playing a
      // track from a smart playlist leaves no transport bar until you pop back.
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
