import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quest_providers.g.dart';

/// One quest as the UI needs it: stored state, blueprint, live progress.
class QuestView {
  const QuestView({
    required this.state,
    required this.template,
    required this.progress,
  });

  final QuestState state;
  final QuestTemplate template;
  final int progress;

  bool get claimed => state.claimed;
  bool get claimable => !claimed && progress >= state.target;
}

@riverpod
Stream<List<QuestState>> questRows(Ref ref) =>
    ref.watch(questServiceProvider).watchDay(HarvestDay.today());

@riverpod
Future<List<QuestView>> todayQuests(Ref ref) async {
  // Re-measure whenever today's check-ins change.
  ref.watch(loggedTodayProvider);
  final rows = ref.watch(questRowsProvider).value ?? const [];
  final service = ref.watch(questServiceProvider);
  final today = HarvestDay.today();

  final views = <QuestView>[];
  for (final state in rows) {
    final template =
        questPool.firstWhere((t) => t.id == state.templateId);
    final progress = state.claimed
        ? state.target
        : await service.measure(template, today);
    views.add(
      QuestView(state: state, template: template, progress: progress),
    );
  }
  return views;
}
