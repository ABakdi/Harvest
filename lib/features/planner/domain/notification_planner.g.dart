// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_planner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationPlanner)
final notificationPlannerProvider = NotificationPlannerProvider._();

final class NotificationPlannerProvider
    extends
        $FunctionalProvider<
          NotificationPlanner,
          NotificationPlanner,
          NotificationPlanner
        >
    with $Provider<NotificationPlanner> {
  NotificationPlannerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPlannerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPlannerHash();

  @$internal
  @override
  $ProviderElement<NotificationPlanner> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPlanner create(Ref ref) {
    return notificationPlanner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPlanner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPlanner>(value),
    );
  }
}

String _$notificationPlannerHash() =>
    r'0cadc11fc104d83243451b42f1e3f8ebd8d4f221';
