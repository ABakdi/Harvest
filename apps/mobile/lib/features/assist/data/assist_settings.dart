import 'package:harvest/core/domain/secure_address.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/assist/data/providers.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assist_settings.g.dart';

enum AssistKind { gemini, openAiCompatible }

abstract final class AssistKeys {
  /// Which provider, and where it answers. None of these syncs or
  /// imports (S5-01): they decide where the key goes.
  static const provider = 'assist.provider';
  static const model = 'assist.model';
  static const baseUrl = 'assist.baseUrl';

  /// The API key's name in secure storage. Never in `kv_settings`:
  /// never exported, never archived, never synced
  /// ([[ADR-013-Assist-Providers]]).
  static const secretKey = 'assist.apiKey';

  /// Where the key was saved for (`gemini`, or `openAiCompatible|<base
  /// URL>`), beside it in secure storage. The key is only handed to that
  /// same destination: a base URL changed any other way than by saving
  /// the key with it does not get the key (S5-01).
  static const secretKeyFor = 'assist.apiKeyFor';

  /// The destination a key is bound to.
  static String destination(AssistKind kind, String baseUrl) => switch (kind) {
    AssistKind.gemini => kind.name,
    AssistKind.openAiCompatible => '${kind.name}|${baseUrl.trim()}',
  };
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
    // Never over plain http to anywhere but this device (S6-12): the
    // key and the prompt would travel in the clear.
    AssistKind.openAiCompatible =>
      baseUrl.isNotEmpty && model.isNotEmpty && isSecureAddress(baseUrl),
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

/// What the signed-in server offers ([[ADR-013-Assist-Providers]]).
///
/// Asked once when the sheet opens, not kept: a server that gains a key
/// tomorrow should offer it tomorrow, and one that has none should not
/// be offered as a provider at all.
@riverpod
Future<AssistProvider?> serverAssist(Ref ref) async {
  final account = await ref.watch(accountControllerProvider.future);
  final me = account.me;
  if (me == null || !me.verified) return null;
  final api = ref.watch(apiClientProvider);
  final Map<String, Object?> status;
  try {
    status = await api
        .get('/v1/assist/status')
        .timeout(const Duration(seconds: 8));
  } on Object {
    // Unreachable, slow or refusing: the server offers nothing now, and
    // the note says where the assist is set up ([[Audit-v3]] U6-01).
    return null;
  }
  if (status['available'] != true) return null;
  return HarvestServerProvider(
    baseUrl: api.baseUrl(),
    accessToken: () async {
      // The client refreshes on its own; this only reads what it has,
      // asking it something harmless first when it holds nothing.
      if (api.tokens.access == null) await api.get('/v1/me');
      return api.tokens.access;
    },
    model: status['model'] as String? ?? 'the server',
  );
}

/// The provider that answers: mine where I set one, the server's
/// otherwise, and none at all when neither is there.
@riverpod
Future<AssistProvider?> assistProviderInUse(Ref ref) async {
  final mine = (await ref.watch(assistSettingsProvider.future)).provider();
  if (mine != null) return mine;
  return ref.watch(serverAssistProvider.future);
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
    final baseUrl = await settings.getString(AssistKeys.baseUrl) ?? '';
    final secrets = ref.read(secretStoreProvider);
    var apiKey = await secrets.read(AssistKeys.secretKey);
    final here = AssistKeys.destination(kind, baseUrl);
    final boundTo = await secrets.read(AssistKeys.secretKeyFor);
    if (apiKey != null && boundTo == null) {
      // Saved before keys were bound: bound now, to where it goes today.
      await secrets.write(AssistKeys.secretKeyFor, here);
    } else if (boundTo != here) {
      apiKey = null;
    }
    return AssistConfig(
      kind: kind,
      model: await settings.getString(AssistKeys.model) ?? '',
      baseUrl: baseUrl,
      apiKey: apiKey,
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
    final secrets = ref.read(secretStoreProvider);
    await secrets.write(AssistKeys.secretKey, apiKey?.trim());
    await secrets.write(
      AssistKeys.secretKeyFor,
      AssistKeys.destination(kind, baseUrl),
    );
    ref.invalidateSelf();
    await future;
  }
}
