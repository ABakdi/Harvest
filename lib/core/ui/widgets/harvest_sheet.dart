import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';

/// The one bottom-sheet body: title, optional subtitle, the form, and
/// the bouncy confirm pinned under it. Keyboard-aware padding included.
class HarvestSheet extends StatelessWidget {
  const HarvestSheet({
    required this.title,
    required this.children,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.scrollable = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Label of the confirm button; omitted when null.
  final String? actionLabel;

  /// Null disables the confirm button.
  final VoidCallback? onAction;

  /// Wrap the form in a scroll view (long forms under the keyboard).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
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
    );
    return Padding(
      padding: EdgeInsets.only(
        left: HarvestSpacing.lg,
        right: HarvestSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + HarvestSpacing.lg,
      ),
      child: scrollable ? SingleChildScrollView(child: column) : column,
    );
  }
}

/// Opens [HarvestSheet] content as a modal bottom sheet with the app's
/// standard shape and keyboard behaviour.
Future<T?> showHarvestSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  builder: builder,
);
