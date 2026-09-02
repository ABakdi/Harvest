import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:harvest/core/ui/tokens.dart';

/// One commitment on the field: title, context line, and either a
/// check circle (habits/to-dos) or a progress ring (projects).
class CropCard extends StatelessWidget {
  const CropCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    required this.onTap,
    this.onLongPress,
    this.progress,
    this.urgent = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 0..1 for projects; null shows a plain check circle.
  final double? progress;

  /// Tints the subtitle in the error color (overdue deadline).
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm + 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(HarvestRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.secondary.withValues(alpha: 0.18),
                child: Icon(icon, color: scheme.secondary),
              ),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? scheme.onSurface.withValues(alpha: 0.5)
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: urgent
                            ? scheme.error
                            : scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: urgent ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              _Trailing(done: done, progress: progress),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.done, this.progress});

  final bool done;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget child;
    if (progress != null) {
      child = SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                done ? scheme.secondary : scheme.primary,
              ),
            ),
            if (done)
              Icon(Icons.check, size: 18, color: scheme.secondary),
          ],
        ),
      );
    } else {
      child = done
          ? CircleAvatar(
              radius: 18,
              backgroundColor: scheme.secondary,
              child: Icon(Icons.check, color: scheme.onSecondary, size: 22),
            )
          : CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.circle_outlined,
                color: scheme.onSurface.withValues(alpha: 0.3),
                size: 32,
              ),
            );
    }

    return child
        .animate(key: ValueKey(done))
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 350.ms,
          curve: Curves.elasticOut,
        );
  }
}
