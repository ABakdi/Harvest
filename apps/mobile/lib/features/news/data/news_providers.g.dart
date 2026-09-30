// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(newsService)
final newsServiceProvider = NewsServiceProvider._();

final class NewsServiceProvider
    extends $FunctionalProvider<NewsService, NewsService, NewsService>
    with $Provider<NewsService> {
  NewsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newsServiceHash();

  @$internal
  @override
  $ProviderElement<NewsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NewsService create(Ref ref) {
    return newsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NewsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NewsService>(value),
    );
  }
}

String _$newsServiceHash() => r'67fd674f4295e24573bfde37d79994e94895faf7';
