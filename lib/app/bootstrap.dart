import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1).
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  await ref.read(streakServiceProvider).reconcile();
  await ref.read(questServiceProvider).ensureGenerated(HarvestDay.today());
}
