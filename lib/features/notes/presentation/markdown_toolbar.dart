import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/notes/domain/markdown_actions.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The bar that sits on the keyboard.
///
/// Markdown is only pleasant to write when the symbols are one tap
/// away; typing `**` on a phone keyboard is three taps and a mode
/// switch. So the syntax I actually use lives here, and the two table
/// buttons appear only when the caret is in a table — a row and column
/// control that is always visible is noise for the ninety per cent of
/// a note that is prose.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({required this.controller, super.key});

  final TextEditingController controller;

  Edit get _at {
    final selection = controller.selection;
    final text = controller.text;
    if (!selection.isValid) return Edit(text, text.length);
    return Edit(
      text,
      selection.start.clamp(0, text.length),
      selection.end.clamp(0, text.length),
    );
  }

  void _apply(Edit? result) {
    if (result == null) return;
    unawaitedTick();
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      ),
    );
  }

  static void unawaitedTick() {
    HarvestHaptics.tick().ignore();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The caret decides whether the table controls are here at all,
    // so the bar has to redraw when the caret moves — the screen
    // above it has no reason to.
    listenable: controller,
    builder: (context, _) => _bar(context),
  );

  Widget _bar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inTable = tableAt(_at) != null;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: HarvestSpacing.xs),
            children: [
              _Action(
                icon: Icons.title,
                tooltip: l10n.mdHeading,
                onTap: () => _apply(cycleHeading(_at)),
              ),
              _Action(
                icon: Icons.format_bold,
                tooltip: l10n.mdBold,
                onTap: () => _apply(toggleWrap(_at, '**')),
              ),
              _Action(
                icon: Icons.format_italic,
                tooltip: l10n.mdItalic,
                onTap: () => _apply(toggleWrap(_at, '*')),
              ),
              _Action(
                icon: Icons.code,
                tooltip: l10n.mdCode,
                onTap: () => _apply(toggleWrap(_at, '`')),
              ),
              const _Separator(),
              _Action(
                icon: Icons.format_list_bulleted,
                tooltip: l10n.mdList,
                onTap: () => _apply(togglePrefix(_at, '- ')),
              ),
              _Action(
                icon: Icons.checklist,
                tooltip: l10n.mdTask,
                onTap: () => _apply(togglePrefix(_at, '- [ ] ')),
              ),
              _Action(
                icon: Icons.format_quote,
                tooltip: l10n.mdQuote,
                onTap: () => _apply(togglePrefix(_at, '> ')),
              ),
              const _Separator(),
              _Action(
                icon: Icons.link,
                tooltip: l10n.mdWikiLink,
                onTap: () => _apply(toggleWrap(_at, '[[')),
              ),
              _Action(
                icon: Icons.table_chart_outlined,
                tooltip: l10n.mdTable,
                onTap: () => _apply(insertTable(_at)),
              ),
              if (inTable) ...[
                const _Separator(),
                _Action(
                  icon: Icons.add_box_outlined,
                  tooltip: l10n.mdTableRow,
                  label: l10n.mdRowShort,
                  onTap: () => _apply(addTableRow(_at)),
                ),
                _Action(
                  icon: Icons.add_box_outlined,
                  tooltip: l10n.mdTableColumn,
                  label: l10n.mdColumnShort,
                  onTap: () => _apply(addTableColumn(_at)),
                ),
              ],
              const _Separator(),
              _Action(
                icon: Icons.keyboard_hide_outlined,
                tooltip: l10n.mdHideKeyboard,
                onTap: () =>
                    SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HarvestRadii.chip),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 8),
          child: Row(
            children: [
              Icon(icon, size: 22, color: scheme.onSurface),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(
                  label!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: HarvestSpacing.xs,
      vertical: 12,
    ),
    child: VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
