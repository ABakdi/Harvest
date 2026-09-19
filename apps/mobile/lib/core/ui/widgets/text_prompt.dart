import 'package:flutter/material.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Asks for one line of text.
///
/// The controller lives inside the dialog rather than in the caller,
/// which sounds like a detail and is not: a controller disposed the
/// moment `await showDialog` returns is a controller still attached to
/// a route that has not finished animating out, and Flutter asserts on
/// exactly that. Owning it here means it dies when the dialog does.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? prefix,
  String? confirmLabel,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPrompt(
    title: title,
    initial: initial,
    hint: hint,
    prefix: prefix,
    confirmLabel: confirmLabel,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    this.hint,
    this.prefix,
    this.confirmLabel,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? prefix;
  final String? confirmLabel;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefix,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l10n.save),
        ),
      ],
    );
  }
}
