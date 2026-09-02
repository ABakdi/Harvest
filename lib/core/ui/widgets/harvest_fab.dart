import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';

/// The screen's primary action, floating: the bouncy gradient button
/// with a soft colored shadow so it reads as the thing to press.
class HarvestFab extends StatelessWidget {
  const HarvestFab({
    required this.onPressed,
    required this.label,
    this.icon = Icons.add,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HarvestRadii.button),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BigBouncyButton(
        onPressed: onPressed,
        icon: icon,
        child: Text(label),
      ),
    );
  }
}
