import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';

/// The one bottom-sheet body: title, optional subtitle, the form, and
/// the bouncy confirm pinned under it.
///
/// The body always scrolls and always reserves the keyboard's height,
/// so however tall the form grows and however short the screen is it
/// can never overflow, and the confirm button stays reachable instead
/// of sitting behind the keyboard.
class HarvestSheet extends StatelessWidget {
  const HarvestSheet({
    required this.title,
    required this.children,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Label of the confirm button; omitted when null.
  final String? actionLabel;

  /// Null disables the confirm button.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // The keyboard, then the gesture bar below it. MediaQuery zeroes
      // the padding an inset already covers, so the two never stack.
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.lg,
          0,
          HarvestSpacing.lg,
          HarvestSpacing.lg,
        ),
        // Dragging the form pushes the keyboard away.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: HarvestSpacing.md),
            ...children,
            if (actionLabel != null) ...[
              const SizedBox(height: HarvestSpacing.lg),
              BigBouncySheetButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens sheet content with the app's standard shape and keyboard
/// behaviour: `useSafeArea` keeps a tall sheet clear of the status bar
/// and `isScrollControlled` lets it grow to the height its form
/// actually needs, instead of stopping at nine sixteenths of the screen.
Future<T?> showHarvestSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);
