import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';

/// One half of a shared tab.
typedef SwitcherHalf<T> = ({T value, IconData icon, String label});

/// The switch under a tab that holds two features.
///
/// The app now has two rules about sub-navigation, and they are
/// different jobs rather than two answers to one:
///
/// * **Top tabs** are views of a single subject — the Granary's Today,
///   Balances and Insights are all the same money.
/// * **This**, at the bottom, is two *separate features* sharing a tab
///   because the bar cannot hold seven. Notes and the Gallery, Health
///   and the Gym, progress and settings.
///
/// It is the app's own segmented button rather than something new, and
/// it sits at the bottom because that is where the thumb already is
/// after tapping the tab.
class FeatureSwitcher<T> extends StatelessWidget {
  const FeatureSwitcher({
    required this.current,
    required this.halves,
    required this.onChanged,
    super.key,
  });

  final T current;
  final List<SwitcherHalf<T>> halves;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.xs,
        HarvestSpacing.md,
        HarvestSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          segments: [
            for (final half in halves)
              ButtonSegment(
                value: half.value,
                icon: Icon(half.icon, size: 18),
                label: Text(half.label),
              ),
          ],
          selected: {current},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            HarvestHaptics.tick().ignore();
            onChanged(selection.first);
          },
        ),
      ),
    ),
  );
}
