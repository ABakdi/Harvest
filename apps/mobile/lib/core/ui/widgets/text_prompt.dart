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
  bool password = false,

  /// The confirm button waits for some text: a name that must not be
  /// empty says so by staying disabled, instead of closing on nothing.
  bool required = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPrompt(
    title: title,
    initial: initial,
    hint: hint,
    prefix: prefix,
    confirmLabel: confirmLabel,
    password: password,
    required: required,
  ),
);

/// Asks for the account's password (S6-06): obscured, never corrected,
/// suggested, learned by the keyboard or capitalised — a capital first
/// letter would turn a right password into a wrong try.
Future<String?> promptForPassword(
  BuildContext context, {
  required String title,
  String? confirmLabel,
}) => promptForText(
  context,
  title: title,
  confirmLabel: confirmLabel,
  password: true,
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    this.hint,
    this.prefix,
    this.confirmLabel,
    this.password = false,
    this.required = false,
  });

  final bool password;
  final bool required;
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

  bool get _ready => !widget.required || _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_ready) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.password,
        autocorrect: !widget.password,
        enableSuggestions: !widget.password,
        enableIMEPersonalizedLearning: !widget.password,
        autofillHints: widget.password ? const [AutofillHints.password] : null,
        keyboardType: widget.password ? TextInputType.visiblePassword : null,
        textCapitalization: widget.password
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefix,
        ),
        onChanged: widget.required ? (_) => setState(() {}) : null,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _ready ? _submit : null,
          child: Text(widget.confirmLabel ?? l10n.save),
        ),
      ],
    );
  }
}
