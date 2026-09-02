import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';

/// A calm empty placeholder: a tinted icon, a short title, one line of
/// guidance, and optionally the action that fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.color,
    this.action,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color? color;
  final Widget? action;

  /// Inline inside a card rather than filling a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.secondary;
    return Padding(
      padding: EdgeInsets.all(compact ? HarvestSpacing.md : HarvestSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon,
            color: accent,
            size: compact ? 48 : 80,
            iconSize: compact ? 24 : 40,
          ),
          SizedBox(height: compact ? HarvestSpacing.sm : HarvestSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (body != null) ...[
            const SizedBox(height: HarvestSpacing.xs),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: HarvestSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
