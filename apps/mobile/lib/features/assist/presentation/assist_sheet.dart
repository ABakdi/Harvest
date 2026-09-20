import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/assist/data/assist_settings.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/assist/domain/prompts.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What the sheet hands back: nothing, or text to put in the note.
typedef AssistOutcome = ({String text, bool replace});

/// Picks an action for a note. Returns null when dismissed.
Future<AssistAction?> pickAssistAction(
  BuildContext context, {
  required bool hasSelection,
}) {
  final l10n = AppLocalizations.of(context);
  return showHarvestSheet<AssistAction>(
    context,
    builder: (context) => HarvestSheet(
      title: l10n.assistTitle,
      children: [
        for (final (action, icon, label) in [
          (AssistAction.summarise, Icons.short_text, l10n.assistSummarise),
          (AssistAction.rewrite, Icons.auto_fix_high, l10n.assistRewrite),
          (AssistAction.continueWriting, Icons.edit_note, l10n.assistContinue),
          (AssistAction.fixGrammar, Icons.spellcheck, l10n.assistFix),
          (AssistAction.translate, Icons.translate, l10n.assistTranslate),
          (AssistAction.ask, Icons.help_outline, l10n.assistAsk),
        ])
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.of(context).pop(action),
          ),
      ],
    ),
  );
}

/// Runs one assist action, showing first what will be sent and to whom
/// (N8), then the answer as it arrives. Insert, Replace and Copy are
/// the only ways it reaches the note (N9).
Future<AssistOutcome?> showAssistSheet(
  BuildContext context, {
  required AssistAction action,
  required String text,
  String upToCaret = '',
  bool fromSelection = false,
  AssistAudio? audio,
}) => showHarvestSheet<AssistOutcome>(
  context,
  builder: (_) => _AssistSheet(
    action: action,
    text: text,
    upToCaret: upToCaret,
    fromSelection: fromSelection,
    audio: audio,
  ),
);

class _AssistSheet extends ConsumerStatefulWidget {
  const _AssistSheet({
    required this.action,
    required this.text,
    required this.upToCaret,
    required this.fromSelection,
    required this.audio,
  });

  final AssistAction action;
  final String text;
  final String upToCaret;
  final bool fromSelection;
  final AssistAudio? audio;

  @override
  ConsumerState<_AssistSheet> createState() => _AssistSheetState();
}

class _AssistSheetState extends ConsumerState<_AssistSheet> {
  final _question = TextEditingController();
  final _answer = StringBuffer();
  StreamSubscription<String>? _stream;
  var _asked = false;
  var _done = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_stream?.cancel());
    _question.dispose();
    super.dispose();
  }

  void _send(AssistProvider provider) {
    final l10n = AppLocalizations.of(context);
    final request = buildRequest(
      widget.action,
      text: widget.text,
      upToCaret: widget.upToCaret,
      question: _question.text.trim(),
      language: Localizations.localeOf(context).languageCode,
      audio: widget.audio,
    );
    setState(() {
      _asked = true;
      _error = null;
      _answer.clear();
    });
    _stream = provider
        .stream(request)
        .listen(
          (chunk) => setState(() => _answer.write(chunk)),
          onError: (Object error) => setState(() {
            _done = true;
            _error = switch (error) {
              AssistException(failure: AssistFailure.badKey) =>
                l10n.assistBadKey,
              AssistException(failure: AssistFailure.quota) => l10n.assistQuota,
              AssistException(failure: AssistFailure.offline) =>
                l10n.assistOffline,
              AssistException(failure: AssistFailure.unsupported) =>
                l10n.assistUnsupported,
              AssistException(:final detail) => l10n.assistFailed(
                detail ?? '',
              ),
              _ => l10n.assistFailed(error.runtimeType.toString()),
            };
          }),
          onDone: () => setState(() => _done = true),
        );
  }

  String _what(AppLocalizations l10n) => switch (widget.action) {
    AssistAction.transcribe => l10n.assistSendsRecording,
    AssistAction.continueWriting => l10n.assistSendsUpToCaret,
    _ when widget.fromSelection => l10n.assistSendsSelection,
    _ => l10n.assistSendsNote,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Mine where I set one, the server's where I am signed in.
    final provider = ref.watch(assistProviderInUseProvider).value;

    if (provider == null) {
      return HarvestSheet(
        title: l10n.assistTitle,
        children: [Text(l10n.assistNeedsSetup)],
      );
    }

    final answer = _answer.toString().trim();
    final ask = widget.action == AssistAction.ask;
    return HarvestSheet(
      title: l10n.assistTitle,
      children: [
        Text(
          l10n.assistSends(_what(l10n), provider.displayName),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (ask) ...[
          const SizedBox(height: HarvestSpacing.sm),
          TextField(
            controller: _question,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.assistQuestionHint),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: HarvestSpacing.md),
        if (!_asked)
          FilledButton.icon(
            onPressed: ask && _question.text.trim().isEmpty
                ? null
                : () => _send(provider),
            icon: const Icon(Icons.send),
            label: Text(l10n.assistGo),
          )
        else ...[
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else
            Container(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(HarvestRadii.chip),
              ),
              child: answer.isEmpty && !_done
                  ? const LinearProgressIndicator()
                  : SelectableText(answer),
            ),
          const SizedBox(height: HarvestSpacing.md),
          if (_done && _error == null && answer.isNotEmpty)
            Wrap(
              spacing: HarvestSpacing.sm,
              runSpacing: HarvestSpacing.sm,
              children: [
                FilledButton.tonal(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((text: answer, replace: false)),
                  child: Text(l10n.assistInsert),
                ),
                if (widget.fromSelection)
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((text: answer, replace: true)),
                    child: Text(l10n.assistReplace),
                  ),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: answer));
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.assistCopied)),
                    );
                  },
                  child: Text(l10n.assistCopy),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
