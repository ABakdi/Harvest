// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_inbox.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What *Share → Harvest* handed over, waiting for the sheet
/// ([[Lists]]: Saving from anywhere).
///
/// The activity keeps the share until asked, because on a cold start it
/// arrives before there is an engine to tell; it also nudges Dart when a
/// share lands in the app while it is open. Either way this takes it,
/// and the shell — the first place inside the navigator — opens the
/// *Save to a list* sheet, as it does for the widget's quick actions.

@ProviderFor(ShareInbox)
final shareInboxProvider = ShareInboxProvider._();

/// What *Share → Harvest* handed over, waiting for the sheet
/// ([[Lists]]: Saving from anywhere).
///
/// The activity keeps the share until asked, because on a cold start it
/// arrives before there is an engine to tell; it also nudges Dart when a
/// share lands in the app while it is open. Either way this takes it,
/// and the shell — the first place inside the navigator — opens the
/// *Save to a list* sheet, as it does for the widget's quick actions.
final class ShareInboxProvider
    extends $NotifierProvider<ShareInbox, SharedDraft?> {
  /// What *Share → Harvest* handed over, waiting for the sheet
  /// ([[Lists]]: Saving from anywhere).
  ///
  /// The activity keeps the share until asked, because on a cold start it
  /// arrives before there is an engine to tell; it also nudges Dart when a
  /// share lands in the app while it is open. Either way this takes it,
  /// and the shell — the first place inside the navigator — opens the
  /// *Save to a list* sheet, as it does for the widget's quick actions.
  ShareInboxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareInboxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareInboxHash();

  @$internal
  @override
  ShareInbox create() => ShareInbox();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedDraft? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedDraft?>(value),
    );
  }
}

String _$shareInboxHash() => r'9d648b307af5803d98e51f05fac2b67166b3da63';

/// What *Share → Harvest* handed over, waiting for the sheet
/// ([[Lists]]: Saving from anywhere).
///
/// The activity keeps the share until asked, because on a cold start it
/// arrives before there is an engine to tell; it also nudges Dart when a
/// share lands in the app while it is open. Either way this takes it,
/// and the shell — the first place inside the navigator — opens the
/// *Save to a list* sheet, as it does for the widget's quick actions.

abstract class _$ShareInbox extends $Notifier<SharedDraft?> {
  SharedDraft? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SharedDraft?, SharedDraft?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SharedDraft?, SharedDraft?>,
              SharedDraft?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
