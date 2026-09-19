// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allNotes)
final allNotesProvider = AllNotesProvider._();

final class AllNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  AllNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return allNotes(ref);
  }
}

String _$allNotesHash() => r'13097cd417274d397adbab1246471f1e68a2fe95';

@ProviderFor(noteFolders)
final noteFoldersProvider = NoteFoldersProvider._();

final class NoteFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  NoteFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return noteFolders(ref);
  }
}

String _$noteFoldersHash() => r'f9ef6598449868aff992f8240aa92e5b0b29ddff';

/// What is in the trash.

@ProviderFor(deletedNotes)
final deletedNotesProvider = DeletedNotesProvider._();

/// What is in the trash.

final class DeletedNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  /// What is in the trash.
  DeletedNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deletedNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deletedNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return deletedNotes(ref);
  }
}

String _$deletedNotesHash() => r'1fa80578afb20aa8fdcc4e986392f61b1b37bbc4';

@ProviderFor(note)
final noteProvider = NoteFamily._();

final class NoteProvider
    extends $FunctionalProvider<AsyncValue<Note?>, Note?, Stream<Note?>>
    with $FutureModifier<Note?>, $StreamProvider<Note?> {
  NoteProvider._({
    required NoteFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteHash();

  @override
  String toString() {
    return r'noteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Note?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Note?> create(Ref ref) {
    final argument = this.argument as String;
    return note(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteHash() => r'2ae16105e635428e57ad2f983836cba1d8ff7c28';

final class NoteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Note?>, String> {
  NoteFamily._()
    : super(
        retry: null,
        name: r'noteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteProvider call(String uuid) => NoteProvider._(argument: uuid, from: this);

  @override
  String toString() => r'noteProvider';
}

@ProviderFor(backlinks)
final backlinksProvider = BacklinksFamily._();

final class BacklinksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  BacklinksProvider._({
    required BacklinksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'backlinksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$backlinksHash();

  @override
  String toString() {
    return r'backlinksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    final argument = this.argument as String;
    return backlinks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BacklinksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$backlinksHash() => r'd5f71fd433998d9cf4dba6544eb1a4bf647452f5';

final class BacklinksFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Note>>, String> {
  BacklinksFamily._()
    : super(
        retry: null,
        name: r'backlinksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BacklinksProvider call(String uuid) =>
      BacklinksProvider._(argument: uuid, from: this);

  @override
  String toString() => r'backlinksProvider';
}

@ProviderFor(outgoingLinks)
final outgoingLinksProvider = OutgoingLinksFamily._();

final class OutgoingLinksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<({String title, String? uuid})>>,
          List<({String title, String? uuid})>,
          Stream<List<({String title, String? uuid})>>
        >
    with
        $FutureModifier<List<({String title, String? uuid})>>,
        $StreamProvider<List<({String title, String? uuid})>> {
  OutgoingLinksProvider._({
    required OutgoingLinksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'outgoingLinksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$outgoingLinksHash();

  @override
  String toString() {
    return r'outgoingLinksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<({String title, String? uuid})>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<({String title, String? uuid})>> create(Ref ref) {
    final argument = this.argument as String;
    return outgoingLinks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OutgoingLinksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$outgoingLinksHash() => r'630e966b892d86e357cddaf469e9f9014ab4c43a';

final class OutgoingLinksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<({String title, String? uuid})>>,
          String
        > {
  OutgoingLinksFamily._()
    : super(
        retry: null,
        name: r'outgoingLinksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OutgoingLinksProvider call(String uuid) =>
      OutgoingLinksProvider._(argument: uuid, from: this);

  @override
  String toString() => r'outgoingLinksProvider';
}
