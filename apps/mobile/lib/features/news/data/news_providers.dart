import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/news/domain/news.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'news_providers.g.dart';

/// News as notifications on the phone, on their own channel.
class LocalNewsNotifier {
  LocalNewsNotifier(this._notifications, this._db);

  final NotificationService _notifications;
  final HarvestDatabase _db;

  /// A stable notification id per piece of news, clear of the
  /// reminders' own ids: the low bits of its hex id above 2^28.
  static int idOf(String id) {
    final tail = id.length > 6 ? id.substring(id.length - 6) : id;
    return 0x10000000 +
        (int.tryParse(tail, radix: 16) ?? tail.hashCode.abs() % 0xFFFFFF);
  }

  Future<void> show(Announcement announcement) async {
    final l10n = await localizationsFromSettings(_db);
    _notifications.channelNames = {
      ..._notifications.channelNames,
      NotificationChannels.news: l10n.channelNews,
    };
    await _notifications.showNews(
      id: idOf(announcement.id),
      title: announcement.title,
      body: announcement.body,
      link: announcement.link,
    );
  }
}

@Riverpod(keepAlive: true)
NewsService newsService(Ref ref) => NewsService(
  api: ref.watch(apiClientProvider),
  settings: ref.watch(settingsRepositoryProvider),
  notify: LocalNewsNotifier(
    ref.watch(notificationServiceProvider),
    ref.watch(databaseProvider),
  ).show,
);

/// The background's own: a fresh database, the built-in server and no
/// session ([[Admin]]: it asks without one).
NewsService backgroundNewsService(HarvestDatabase db) => NewsService(
  api: ApiClient(
    baseUrl: () => Uri.parse(harvestServerUrl),
    tokens: TokenStore(const _NoSession()),
  ),
  settings: SettingsRepository(db),
  notify: LocalNewsNotifier(NotificationService(), db).show,
);

/// No session at all: the background never holds one.
class _NoSession implements SecretStore {
  const _NoSession();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String? value) async {}
}
