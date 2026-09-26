// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_gateways.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(voiceRecorder)
final voiceRecorderProvider = VoiceRecorderProvider._();

final class VoiceRecorderProvider
    extends $FunctionalProvider<VoiceRecorder, VoiceRecorder, VoiceRecorder>
    with $Provider<VoiceRecorder> {
  VoiceRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceRecorderHash();

  @$internal
  @override
  $ProviderElement<VoiceRecorder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoiceRecorder create(Ref ref) {
    return voiceRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceRecorder>(value),
    );
  }
}

String _$voiceRecorderHash() => r'5991e52f4e725ed23a53acc859e643f9a0be9c50';

@ProviderFor(dictation)
final dictationProvider = DictationProvider._();

final class DictationProvider
    extends $FunctionalProvider<Dictation, Dictation, Dictation>
    with $Provider<Dictation> {
  DictationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictationHash();

  @$internal
  @override
  $ProviderElement<Dictation> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dictation create(Ref ref) {
    return dictation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dictation value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dictation>(value),
    );
  }
}

String _$dictationHash() => r'911cd856fab72dbc49a192085af8015ebbab1991';

@ProviderFor(speaker)
final speakerProvider = SpeakerProvider._();

final class SpeakerProvider
    extends $FunctionalProvider<Speaker, Speaker, Speaker>
    with $Provider<Speaker> {
  SpeakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speakerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speakerHash();

  @$internal
  @override
  $ProviderElement<Speaker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Speaker create(Ref ref) {
    return speaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Speaker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Speaker>(value),
    );
  }
}

String _$speakerHash() => r'e67530e0f48b2fd911383c62e52b9740ea23077b';
