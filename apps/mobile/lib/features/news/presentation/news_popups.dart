import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/news/data/news_providers.dart';
import 'package:harvest/features/news/domain/news.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asks for the news when the app opens and whenever it comes back,
/// and shows each pop-up not shown yet, once, one after the other
/// ([[Admin]]). Sits above every tab, beside the sync PIN's prompt.
class NewsPopups extends ConsumerStatefulWidget {
  const NewsPopups({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NewsPopups> createState() => _NewsPopupsState();
}

class _NewsPopupsState extends ConsumerState<NewsPopups> {
  AppLifecycleListener? _lifecycle;
  var _showing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_showing || !mounted) return;
    _showing = true;
    try {
      final account = await ref.read(accountControllerProvider.future);
      final service = ref.read(newsServiceProvider);
      await _askToNotifyOnce(service);
      final popups = await service.check(signedIn: account.signedIn);
      for (final piece in popups) {
        if (!mounted) return;
        await showNewsDialog(context, piece);
        await service.markShown(piece.id);
      }
    } on Object catch (error) {
      debugPrint('[news] not shown: ${error.runtimeType}');
    } finally {
      _showing = false;
    }
  }

  /// News on and never asked: asks, once, to post notifications, so a
  /// push can reach a phone whose reminders are off. Asked with the app
  /// in front, never from the background.
  Future<void> _askToNotifyOnce(NewsService service) async {
    if (!await service.enabled()) return;
    final settings = ref.read(settingsRepositoryProvider);
    if (await settings.getBool(NewsKeys.permissionAsked) ?? false) return;
    await settings.setBool(NewsKeys.permissionAsked, value: true);
    await ref.read(notificationServiceProvider).requestPostPermission();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One piece of news in a dialog: its title, its body, a button to its
/// link when it has one, and one to put it away.
Future<void> showNewsDialog(BuildContext context, Announcement piece) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(piece.title),
          content: SingleChildScrollView(child: Text(piece.body)),
          actions: [
            if (piece.link != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(openNewsLink(piece.link!));
                },
                child: Text(l10n.newsOpenLink),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.newsDismiss),
            ),
          ],
        );
      },
    );

/// Opens a piece of news's link in the browser; only ever `https://`.
Future<void> openNewsLink(String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null || !uri.isScheme('https')) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (error) {
    debugPrint('[news] link not opened: ${error.runtimeType}');
  }
}
