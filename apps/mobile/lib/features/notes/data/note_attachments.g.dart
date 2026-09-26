// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_attachments.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(attachmentStorage)
final attachmentStorageProvider = AttachmentStorageProvider._();

final class AttachmentStorageProvider
    extends
        $FunctionalProvider<
          AttachmentStorage,
          AttachmentStorage,
          AttachmentStorage
        >
    with $Provider<AttachmentStorage> {
  AttachmentStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentStorageHash();

  @$internal
  @override
  $ProviderElement<AttachmentStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentStorage create(Ref ref) {
    return attachmentStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentStorage>(value),
    );
  }
}

String _$attachmentStorageHash() => r'412e1345dc0bde76c0b31716409333250db9d7ae';

@ProviderFor(noteAttachmentsRepository)
final noteAttachmentsRepositoryProvider = NoteAttachmentsRepositoryProvider._();

final class NoteAttachmentsRepositoryProvider
    extends
        $FunctionalProvider<
          NoteAttachmentsRepository,
          NoteAttachmentsRepository,
          NoteAttachmentsRepository
        >
    with $Provider<NoteAttachmentsRepository> {
  NoteAttachmentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteAttachmentsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteAttachmentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NoteAttachmentsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NoteAttachmentsRepository create(Ref ref) {
    return noteAttachmentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteAttachmentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteAttachmentsRepository>(value),
    );
  }
}

String _$noteAttachmentsRepositoryHash() =>
    r'01602f81f02e76be70ebd646bed3d36e87264b5f';

@ProviderFor(noteAttachments)
final noteAttachmentsProvider = NoteAttachmentsFamily._();

final class NoteAttachmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NoteAttachment>>,
          List<NoteAttachment>,
          Stream<List<NoteAttachment>>
        >
    with
        $FutureModifier<List<NoteAttachment>>,
        $StreamProvider<List<NoteAttachment>> {
  NoteAttachmentsProvider._({
    required NoteAttachmentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteAttachmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteAttachmentsHash();

  @override
  String toString() {
    return r'noteAttachmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<NoteAttachment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<NoteAttachment>> create(Ref ref) {
    final argument = this.argument as String;
    return noteAttachments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteAttachmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteAttachmentsHash() => r'a0077cea633a873c4266741fde5b55ef46d84ba4';

final class NoteAttachmentsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<NoteAttachment>>, String> {
  NoteAttachmentsFamily._()
    : super(
        retry: null,
        name: r'noteAttachmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteAttachmentsProvider call(String noteUuid) =>
      NoteAttachmentsProvider._(argument: noteUuid, from: this);

  @override
  String toString() => r'noteAttachmentsProvider';
}
