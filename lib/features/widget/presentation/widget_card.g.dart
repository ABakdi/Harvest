// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_card.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The three switchable sections, live.

@ProviderFor(widgetSections)
final widgetSectionsProvider = WidgetSectionsProvider._();

/// The three switchable sections, live.

final class WidgetSectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, bool>>,
          Map<String, bool>,
          Stream<Map<String, bool>>
        >
    with
        $FutureModifier<Map<String, bool>>,
        $StreamProvider<Map<String, bool>> {
  /// The three switchable sections, live.
  WidgetSectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetSectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetSectionsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, bool>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, bool>> create(Ref ref) {
    return widgetSections(ref);
  }
}

String _$widgetSectionsHash() => r'6e51f623b9a7e3a91e358945bd4436273c610ce8';
