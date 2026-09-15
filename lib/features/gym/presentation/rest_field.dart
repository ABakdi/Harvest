import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The rest between sets: the six usual answers as chips, and a box
/// for the seventh.
///
/// The chips were the whole control once, and 150 seconds was not a
/// rest the app could be told about ([[Checkpoint-6]]). The box takes
/// seconds because that is what the chips say; a value typed there is
/// committed when the keyboard's done key is pressed, and shows up
/// selected the way a chip would.
class RestField extends StatefulWidget {
  const RestField({
    required this.seconds,
    required this.onChanged,
    super.key,
  });

  /// The current rest, or null for none set.
  final int? seconds;
  final ValueChanged<int> onChanged;

  @override
  State<RestField> createState() => _RestFieldState();
}

class _RestFieldState extends State<RestField> {
  late final TextEditingController _custom = TextEditingController(
    text: _isCustom(widget.seconds) ? '${widget.seconds}' : '',
  );

  static bool _isCustom(int? seconds) =>
      seconds != null && !restChoices.contains(seconds);

  @override
  void didUpdateWidget(RestField old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds) {
      _custom.text = _isCustom(widget.seconds) ? '${widget.seconds}' : '';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _commit() {
    final value = int.tryParse(_custom.text.trim());
    if (value == null || value <= 0) return;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final custom = _isCustom(widget.seconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: HarvestSpacing.xs,
          runSpacing: HarvestSpacing.xs,
          children: [
            for (final seconds in restChoices)
              ChoiceChip(
                label: Text(l10n.gymRestSeconds(seconds)),
                selected: widget.seconds == seconds,
                onSelected: (_) => widget.onChanged(seconds),
              ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Row(
          children: [
            Text(
              l10n.gymRestCustom,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _custom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commit(),
                onEditingComplete: _commit,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.gymRestCustomHint,
                  suffixText: 's',
                  filled: true,
                  fillColor: custom
                      ? scheme.secondary.withValues(alpha: 0.18)
                      : scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: HarvestSpacing.sm,
                    vertical: HarvestSpacing.xs,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HarvestRadii.chip),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
