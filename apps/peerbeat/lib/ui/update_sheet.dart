import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../update/updater.dart';

/// A non-blocking banner offering the [info] update: Update · Later · Skip.
void showUpdateBanner(BuildContext context, UpdateInfo info) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showMaterialBanner(
    MaterialBanner(
      leading: const Icon(Icons.system_update_outlined),
      content: Text(l10n.updateAvailable(info.version)),
      actions: [
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            updater.skip(info.version);
            updater.dismiss();
          },
          child: Text(l10n.updateSkip),
        ),
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            updater.dismiss();
          },
          child: Text(l10n.updateLater),
        ),
        FilledButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            updater.dismiss();
            runUpdateFlow(context, info);
          },
          child: Text(l10n.updateNow),
        ),
      ],
    ),
  );
}

/// Show the download → install dialog for [info].
Future<void> runUpdateFlow(BuildContext context, UpdateInfo info) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(info: info),
    );

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress; // null until download starts
  bool _installing = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final file = await updater.download(widget.info, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _installing = true);
      // Windows: this exits the app so the installer can replace it.
      // Android: hands off to the system package installer (user confirms).
      await updater.install(file);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final downloading = _progress != null && !_installing;
    final busy = _progress != null;
    final notes = widget.info.notes;
    return AlertDialog(
      title: Text(l10n.updateToVersion(widget.info.version)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notes.isNotEmpty && !busy) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(child: Text(notes)),
              ),
              const SizedBox(height: 16),
            ],
            if (downloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(l10n.downloadingPercent(((_progress ?? 0) * 100).round())),
            ],
            if (_installing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(l10n.startingInstaller),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: busy ? null : _start,
          child: Text(
            _error != null ? l10n.commonRetry : l10n.downloadAndInstall,
          ),
        ),
      ],
    );
  }
}
