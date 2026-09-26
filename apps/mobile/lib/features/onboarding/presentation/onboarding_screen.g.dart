// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether first-run onboarding has been completed. The real value is
/// loaded before the app starts; defaulting to true protects existing
/// users from ever seeing onboarding again by accident.

@ProviderFor(OnboardingDone)
final onboardingDoneProvider = OnboardingDoneProvider._();

/// Whether first-run onboarding has been completed. The real value is
/// loaded before the app starts; defaulting to true protects existing
/// users from ever seeing onboarding again by accident.
final class OnboardingDoneProvider
    extends $NotifierProvider<OnboardingDone, bool> {
  /// Whether first-run onboarding has been completed. The real value is
  /// loaded before the app starts; defaulting to true protects existing
  /// users from ever seeing onboarding again by accident.
  OnboardingDoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingDoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingDoneHash();

  @$internal
  @override
  OnboardingDone create() => OnboardingDone();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$onboardingDoneHash() => r'211678cfe4d9f60c95293073be15f9488158806d';

/// Whether first-run onboarding has been completed. The real value is
/// loaded before the app starts; defaulting to true protects existing
/// users from ever seeing onboarding again by accident.

abstract class _$OnboardingDone extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
