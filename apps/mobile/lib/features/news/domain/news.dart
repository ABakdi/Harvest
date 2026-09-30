import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

/// A piece of news from Harvest ([[Admin]]): a notification, a pop-up
/// shown once when the app opens, or both.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.push,
    required this.popup,
    this.link,
  });

  final String id;
  final String title;
  final String body;

  /// An `https://` address, opened by the button under the body.
  final String? link;
  final bool push;
  final bool popup;

  /// Null for anything that is not one: a newer server's news the phone
  /// does not understand is left alone, not shown half.
  static Announcement? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final body = raw['body'];
    final link = raw['link'];
    if (id is! String || title is! String || body is! String) return null;
    final safeLink =
        link is String && Uri.tryParse(link)?.isScheme('https') == true
        ? link
        : null;
    return Announcement(
      id: id,
      title: title,
      body: body,
      link: safeLink,
      push: raw['push'] == true,
      popup: raw['popup'] == true,
    );
  }
}

/// This phone's own news bookkeeping: never synced (`news.` is not a
/// portable prefix), so each device shows each piece once.
abstract final class NewsKeys {
  /// *News from Harvest*: on unless turned off.
  static const enabled = 'news.enabled';

  /// The ids already notified, and already shown as a pop-up.
  static const notified = 'news.notified';
  static const shown = 'news.shown';

  /// When the app last asked, so opening it again and again does not.
  static const askedAt = 'news.askedAt';

  /// Whether the phone has been asked, once, to let news notify.
  static const permissionAsked = 'news.permissionAsked';
}

/// How a phone shows a notification: the local notifications plugin on
/// device, a recorder in tests.
typedef ShowNews = Future<void> Function(Announcement announcement);

/// Asks the server for the news and says each piece once ([[Admin]]).
///
/// Everything is remembered here, on the phone: the server learns
/// nothing about who read what, and without a session it does not even
/// learn who asked (AD5). Turned off, it asks nothing.
class NewsService {
  NewsService({
    required this.api,
    required this.settings,
    required this.notify,
  });

  final ApiClient api;
  final SettingsRepository settings;
  final ShowNews notify;

  /// How often opening the app asks again.
  static const askEvery = Duration(minutes: 15);

  /// How many ids of each kind are remembered; old news is long gone.
  static const remembered = 200;

  Future<bool> enabled() async =>
      await settings.getBool(NewsKeys.enabled) ?? true;

  /// Asks for the news, notifies what has not been notified, and
  /// answers the pop-ups not shown yet, oldest first. [signedIn] asks
  /// with the session, for news meant for account holders; the
  /// background asks without one. [force] ignores [askEvery].
  Future<List<Announcement>> check({
    required bool signedIn,
    bool force = false,
    DateTime? now,
  }) async {
    if (!await enabled()) return const [];
    final at = now ?? DateTime.now();
    if (!force) {
      final asked = DateTime.tryParse(
        await settings.getString(NewsKeys.askedAt) ?? '',
      );
      if (asked != null && at.difference(asked) < askEvery) {
        return const [];
      }
    }
    final List<Announcement> news;
    try {
      final json = signedIn
          ? await api.get('/v1/announcements')
          : await api.getAnonymous('/v1/announcements');
      final list = json['announcements'];
      news = [
        if (list is List)
          for (final raw in list) ?Announcement.fromJson(raw),
      ];
    } on Object catch (error) {
      debugPrint('[news] not asked: ${error.runtimeType}');
      return const [];
    }
    await settings.setString(NewsKeys.askedAt, at.toIso8601String());

    final notified = await _ids(NewsKeys.notified);
    for (final piece in news) {
      if (!piece.push || notified.contains(piece.id)) continue;
      await notify(piece);
      notified.add(piece.id);
    }
    await _keep(NewsKeys.notified, notified);

    final shown = await _ids(NewsKeys.shown);
    // The server answers newest first; a pop-up reads oldest first.
    return [
      for (final piece in news.reversed)
        if (piece.popup && !shown.contains(piece.id)) piece,
    ];
  }

  /// Remembers that [id] was shown as a pop-up.
  Future<void> markShown(String id) async {
    final shown = await _ids(NewsKeys.shown)
      ..add(id);
    await _keep(NewsKeys.shown, shown);
  }

  Future<List<String>> _ids(String key) async {
    try {
      final raw = jsonDecode(await settings.getString(key) ?? '[]');
      return [if (raw is List) ...raw.whereType<String>()];
    } on FormatException {
      return [];
    }
  }

  Future<void> _keep(String key, List<String> ids) => settings.setString(
    key,
    jsonEncode(
      ids.length > remembered ? ids.sublist(ids.length - remembered) : ids,
    ),
  );
}
