import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/assist/data/assist_settings.dart';
import 'package:harvest/features/assist/data/providers.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Settings → Extras → Assist ([[ADR-013-Assist-Providers]]): which
/// provider, which model, and my own key.
class AssistSettingsCard extends ConsumerStatefulWidget {
  const AssistSettingsCard({super.key});

  @override
  ConsumerState<AssistSettingsCard> createState() => _AssistSettingsCardState();
}

class _AssistSettingsCardState extends ConsumerState<AssistSettingsCard> {
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _key = TextEditingController();
  AssistKind _kind = AssistKind.gemini;
  var _loaded = false;
  var _busy = false;
  var _hideKey = true;

  @override
  void initState() {
    super.initState();
    // Filled once, from the first data: a field that has not heard from
    // storage yet is not a key I cleared ([[Audit-v2]] U3-02).
    ref.listenManual(assistSettingsProvider, (_, next) {
      final config = next.value;
      if (config == null || _loaded) return;
      setState(() {
        _loaded = true;
        _kind = config.kind;
        _model.text = config.model;
        _baseUrl.text = config.baseUrl;
        _key.text = config.apiKey ?? '';
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _model.dispose();
    _baseUrl.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await ref
        .read(assistSettingsProvider.notifier)
        .save(
          kind: _kind,
          model: _model.text,
          baseUrl: _baseUrl.text,
          apiKey: _key.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.assistSaved)));
  }

  Future<void> _test() async {
    await _save();
    final config = ref.read(assistSettingsProvider).value;
    final provider = config?.provider();
    if (provider == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String message;
    try {
      await provider
          .stream(
            const AssistRequest(
              system: 'Answer with the single word: ok',
              messages: [AssistMessage.user('ping')],
            ),
          )
          .drain<void>();
      message = l10n.assistTestOk;
    } on AssistException catch (error) {
      message = switch (error.failure) {
        AssistFailure.badKey => l10n.assistBadKey,
        AssistFailure.quota => l10n.assistQuota,
        AssistFailure.offline => l10n.assistOffline,
        AssistFailure.unsupported => l10n.assistUnsupported,
        AssistFailure.other => l10n.assistFailed(error.detail ?? ''),
      };
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: HarvestSpacing.xs),
            Text(
              l10n.assistHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            SegmentedButton<AssistKind>(
              segments: [
                ButtonSegment(
                  value: AssistKind.gemini,
                  label: Text(l10n.assistGemini),
                ),
                ButtonSegment(
                  value: AssistKind.openAiCompatible,
                  label: Text(l10n.assistOpenAi),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            TextField(
              controller: _model,
              decoration: InputDecoration(
                labelText: l10n.assistModel,
                hintText: _kind == AssistKind.gemini
                    ? GeminiProvider.defaultModel
                    : 'gpt-4o-mini',
              ),
            ),
            if (_kind == AssistKind.openAiCompatible) ...[
              const SizedBox(height: HarvestSpacing.sm),
              TextField(
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.assistBaseUrl,
                  hintText: 'https://api.openai.com/v1',
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.sm),
            TextField(
              controller: _key,
              obscureText: _hideKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.assistKey,
                helperText: l10n.assistKeyHint,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: l10n.assistKey,
                  icon: Icon(
                    _hideKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hideKey = !_hideKey),
                ),
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => unawaited(_save()),
                  child: Text(l10n.assistSave),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                OutlinedButton(
                  onPressed: _busy ? null : () => unawaited(_test()),
                  child: Text(l10n.assistTest),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
