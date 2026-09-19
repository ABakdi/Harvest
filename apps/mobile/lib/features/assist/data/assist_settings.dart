import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/assist/data/providers.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assist_settings.g.dart';

enum AssistKind { gemini, openAiCompatible }

abstract final class AssistKeys {
  /// Which provider: a preference, so it syncs with the others.
  static const provider = 'assist.provider';
  static const model = 'assist.model';
  static const baseUrl = 'assist.baseUrl';

  /// The API key's name in secure storage. Never in `kv_settings`:
  /// never exported, never archived, never synced
  /// ([[ADR-013-Assist-Providers]]).
  static const secretKey = 'assist.apiKey';
}

/// The assist as configured, key included (in memory only).
@immutable
class AssistConfig {
  const AssistConfig({
    required this.kind,
    required this.model,
    required this.baseUrl,
    required this.apiKey,
  });

  final AssistKind kind;
  final String model;
  final String baseUrl;
  final String? apiKey;

  bool get ready => switch (kind) {
    AssistKind.gemini => apiKey?.isNotEmpty ?? false,
    // A local server may need no key at all; a base URL is enough.
    AssistKind.openAiCompatible => baseUrl.isNotEmpty && model.isNotEmpty,
  };

  /// The provider this configuration names, or null until it is usable.
  AssistProvider? provider() {
    if (!ready) return null;
    return switch (kind) {
      AssistKind.gemini => GeminiProvider(
        apiKey: apiKey!,
        model: model.isEmpty ? GeminiProvider.defaultModel : model,
      ),
      AssistKind.openAiCompatible => OpenAiCompatibleProvider(
        apiKey: apiKey ?? '',
        model: model,
        baseUrl: baseUrl,
      ),
    };
  }
}

/// Reads and writes the assist's configuration.
@Riverpod(keepAlive: true)
class AssistSettings extends _$AssistSettings {
  @override
  Future<AssistConfig> build() async {
    final settings = ref.watch(settingsRepositoryProvider);
    final stored = await settings.getString(AssistKeys.provider);
    final kind =
        AssistKind.values.where((k) => k.name == stored).firstOrNull ??
        AssistKind.gemini;
    return AssistConfig(
      kind: kind,
      model: await settings.getString(AssistKeys.model) ?? '',
      baseUrl: await settings.getString(AssistKeys.baseUrl) ?? '',
      apiKey: await ref.read(secretStoreProvider).read(AssistKeys.secretKey),
    );
  }

  Future<void> save({
    required AssistKind kind,
    required String model,
    required String baseUrl,
    required String? apiKey,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setString(AssistKeys.provider, kind.name);
    await settings.setString(AssistKeys.model, model.trim());
    await settings.setString(AssistKeys.baseUrl, baseUrl.trim());
    await ref
        .read(secretStoreProvider)
        .write(AssistKeys.secretKey, apiKey?.trim());
    ref.invalidateSelf();
    await future;
  }
}
