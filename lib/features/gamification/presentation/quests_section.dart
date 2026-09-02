import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:harvest/features/gamification/presentation/quest_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The four daily micro-quests, shown above the field.
class QuestsSection extends ConsumerWidget {
  const QuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final quests = ref.watch(todayQuestsProvider).value ?? const [];
    if (quests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HarvestSpacing.md),
          child: Text(
            l10n.questsTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
            ),
            itemCount: quests.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HarvestSpacing.sm),
            itemBuilder: (context, index) =>
                _QuestCard(view: quests[index]),
          ),
        ),
      ],
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.view});

  final QuestView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = switch (view.template.id) {
      'habits2' => l10n.questHabits2,
      'habitsEarly' => l10n.questHabitsEarly,
      'projectUnits20' => l10n.questProjectUnits20,
      'todos2' => l10n.questTodos2,
      'logExpenses' => l10n.questLogExpenses,
      _ => l10n.questActions4,
    };
    final reward = view.template.reward == QuestReward.xp
        ? l10n.xpEarned(view.template.amount)
        : l10n.rewardCoins(view.template.amount);

    return SizedBox(
      width: 240,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  decoration:
                      view.claimed ? TextDecoration.lineThrough : null,
                ),
              ),
              const Spacer(),
              if (view.claimable)
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: HarvestSpacing.md,
                      ),
                    ),
                    onPressed: () async {
                      final claimed = await ref
                          .read(questServiceProvider)
                          .claim(view.state.uuid);
                      if (claimed) unawaited(HarvestHaptics.thud());
                    },
                    child: Text('${l10n.claim} · $reward'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(HarvestRadii.chip),
                        child: LinearProgressIndicator(
                          value: (view.progress / view.state.target)
                              .clamp(0, 1)
                              .toDouble(),
                          minHeight: 6,
                          backgroundColor:
                              scheme.onSurface.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            view.claimed ? scheme.secondary : scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: HarvestSpacing.sm),
                    Text(
                      view.claimed
                          ? reward
                          : '${view.progress}/${view.state.target}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: view.claimed
                            ? scheme.secondary
                            : scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
