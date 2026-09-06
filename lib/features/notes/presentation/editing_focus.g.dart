// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editing_focus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether a note's body currently has the caret.
///
/// Three widgets in three different parts of the tree need to know:
/// the editor puts its toolbar up, the Records switch gets out of the
/// way, and neither can ask the other. The keyboard's own inset would
/// be the obvious signal, except a Scaffold eats it before the screens
/// underneath can see it — so the fact is stated once, here.

@ProviderFor(WritingNote)
final writingNoteProvider = WritingNoteProvider._();

/// Whether a note's body currently has the caret.
///
/// Three widgets in three different parts of the tree need to know:
/// the editor puts its toolbar up, the Records switch gets out of the
/// way, and neither can ask the other. The keyboard's own inset would
/// be the obvious signal, except a Scaffold eats it before the screens
/// underneath can see it — so the fact is stated once, here.
final class WritingNoteProvider extends $NotifierProvider<WritingNote, bool> {
  /// Whether a note's body currently has the caret.
  ///
  /// Three widgets in three different parts of the tree need to know:
  /// the editor puts its toolbar up, the Records switch gets out of the
  /// way, and neither can ask the other. The keyboard's own inset would
  /// be the obvious signal, except a Scaffold eats it before the screens
  /// underneath can see it — so the fact is stated once, here.
  WritingNoteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'writingNoteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$writingNoteHash();

  @$internal
  @override
  WritingNote create() => WritingNote();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$writingNoteHash() => r'1d9eb2ec17a6c616058ea94f550a1532652f7db9';

/// Whether a note's body currently has the caret.
///
/// Three widgets in three different parts of the tree need to know:
/// the editor puts its toolbar up, the Records switch gets out of the
/// way, and neither can ask the other. The keyboard's own inset would
/// be the obvious signal, except a Scaffold eats it before the screens
/// underneath can see it — so the fact is stated once, here.

abstract class _$WritingNote extends $Notifier<bool> {
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
