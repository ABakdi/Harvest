import 'package:harvest/core/db/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
HarvestDatabase database(Ref ref) {
  final db = HarvestDatabase();
  ref.onDispose(db.close);
  return db;
}
