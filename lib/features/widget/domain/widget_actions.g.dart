// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The action a widget button asked for, waiting to be carried out.
///
/// The shell watches this and opens the sheet, because a home-screen
/// button cannot open a bottom sheet by itself: it can only start the
/// activity with a URI attached, and something inside the navigator has
/// to notice.

@ProviderFor(PendingWidgetAction)
final pendingWidgetActionProvider = PendingWidgetActionProvider._();

/// The action a widget button asked for, waiting to be carried out.
///
/// The shell watches this and opens the sheet, because a home-screen
/// button cannot open a bottom sheet by itself: it can only start the
/// activity with a URI attached, and something inside the navigator has
/// to notice.
final class PendingWidgetActionProvider
    extends $NotifierProvider<PendingWidgetAction, WidgetAction?> {
  /// The action a widget button asked for, waiting to be carried out.
  ///
  /// The shell watches this and opens the sheet, because a home-screen
  /// button cannot open a bottom sheet by itself: it can only start the
  /// activity with a URI attached, and something inside the navigator has
  /// to notice.
  PendingWidgetActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingWidgetActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingWidgetActionHash();

  @$internal
  @override
  PendingWidgetAction create() => PendingWidgetAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetAction? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetAction?>(value),
    );
  }
}

String _$pendingWidgetActionHash() =>
    r'3144024f3e3b2e2323c03a44306a4500422dbf1e';

/// The action a widget button asked for, waiting to be carried out.
///
/// The shell watches this and opens the sheet, because a home-screen
/// button cannot open a bottom sheet by itself: it can only start the
/// activity with a URI attached, and something inside the navigator has
/// to notice.

abstract class _$PendingWidgetAction extends $Notifier<WidgetAction?> {
  WidgetAction? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WidgetAction?, WidgetAction?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WidgetAction?, WidgetAction?>,
              WidgetAction?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
