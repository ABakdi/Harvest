import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';

/// The headline surface of a screen: a gradient (or tinted) card that
/// carries one big number and the actions around it. Content inside is
/// white on gradients and inherits the tint color on tinted cards.
class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.child,
    this.gradient,
    this.tint,
    this.padding = const EdgeInsets.all(HarvestSpacing.lg),
    this.onTap,
    super.key,
  });

  /// Uses the theme's signature gradient when neither is given.
  final LinearGradient? gradient;

  /// A soft tinted card (status colors) instead of a gradient.
  final Color? tint;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tinted = tint != null;
    final effectiveGradient = tinted
        ? null
        : (gradient ?? theme.primaryGradient);
    final foreground = tinted ? theme.colorScheme.onSurface : Colors.white;
    final shadowColor = tinted ? tint! : effectiveGradient!.colors.first;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HarvestRadii.card + 4),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: tinted ? 0.12 : 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(HarvestRadii.card + 4),
        child: Ink(
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            color: tinted ? tint!.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(HarvestRadii.card + 4),
            border: tinted
                ? Border.all(color: tint!.withValues(alpha: 0.4))
                : null,
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding,
              // Re-key the text theme so styles pulled from it inside
              // the card carry the card's foreground, not the page's.
              child: Theme(
                data: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    bodyColor: foreground,
                    displayColor: foreground,
                  ),
                  iconTheme: theme.iconTheme.copyWith(color: foreground),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase caption used inside hero cards and tiles.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.color;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: (color ?? base)?.withValues(alpha: 0.75),
      ),
    );
  }
}
