// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rates_card.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The raw rate settings as stored, for the card's fields.

@ProviderFor(rateSettings)
final rateSettingsProvider = RateSettingsProvider._();

/// The raw rate settings as stored, for the card's fields.

final class RateSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          Stream<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $StreamProvider<Map<String, String>> {
  /// The raw rate settings as stored, for the card's fields.
  RateSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rateSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rateSettingsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, String>> create(Ref ref) {
    return rateSettings(ref);
  }
}

String _$rateSettingsHash() => r'4965e8194fdefc22819a55abc5966c1f6bd12c52';
