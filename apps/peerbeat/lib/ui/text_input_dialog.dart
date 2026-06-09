import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a single-text-field dialog and returns the entered text, or null if the
/// user cancelled (or submitted nothing distinguishable from cancel — callers
/// trim/validate).
///
/// The [TextEditingController] is owned by the dialog's [State] and disposed in
/// [State.dispose], which runs only AFTER the route's exit transition completes.
/// Disposing a locally-created controller in a `finally` right after
/// `await showDialog` instead races that transition: the still-mounted TextField
/// rebuilds during the dismiss animation and touches the disposed controller
/// ("A TextEditingController was used after being disposed"), corrupting the
/// element tree and cascading into a full-screen crash.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initialText = '',
  String? label,
  String? hint,
  String confirmLabel = 'OK',
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      initialText: initialText,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialText,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.keyboardType,
  });

  final String title;
  final String initialText;
  final String? label;
  final String? hint;
  final String confirmLabel;
  final TextInputType? keyboardType;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
