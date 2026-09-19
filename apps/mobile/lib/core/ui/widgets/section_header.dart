import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';

/// The one way a section starts: a bold title, an optional quiet
/// subtitle, and room for a trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: HarvestSpacing.lg,
      bottom: HarvestSpacing.sm,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
