// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_day.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The live Harvest Day. Everything keyed on "today" watches this
/// instead of calling [HarvestDay.today] once and freezing: it ticks
/// over by itself at the 3 AM boundary and can be nudged on resume.

@ProviderFor(CurrentHarvestDay)
final currentHarvestDayProvider = CurrentHarvestDayProvider._();

/// The live Harvest Day. Everything keyed on "today" watches this
/// instead of calling [HarvestDay.today] once and freezing: it ticks
/// over by itself at the 3 AM boundary and can be nudged on resume.
final class CurrentHarvestDayProvider
    extends $NotifierProvider<CurrentHarvestDay, HarvestDay> {
  /// The live Harvest Day. Everything keyed on "today" watches this
  /// instead of calling [HarvestDay.today] once and freezing: it ticks
  /// over by itself at the 3 AM boundary and can be nudged on resume.
  CurrentHarvestDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentHarvestDayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentHarvestDayHash();

  @$internal
  @override
  CurrentHarvestDay create() => CurrentHarvestDay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HarvestDay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HarvestDay>(value),
    );
  }
}

String _$currentHarvestDayHash() => r'5100a9e4a919cd53a3ef246a319bfa8b6744a7e0';

/// The live Harvest Day. Everything keyed on "today" watches this
/// instead of calling [HarvestDay.today] once and freezing: it ticks
/// over by itself at the 3 AM boundary and can be nudged on resume.

abstract class _$CurrentHarvestDay extends $Notifier<HarvestDay> {
  HarvestDay build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HarvestDay, HarvestDay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HarvestDay, HarvestDay>,
              HarvestDay,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
