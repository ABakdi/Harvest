// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rates_card.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rateSettings)
final rateSettingsProvider = RateSettingsProvider._();

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

String _$rateSettingsHash() => r'52077292739a729cd877db317aad9163fc009983';
