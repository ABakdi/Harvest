import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One turn of what is sent: mine, or an earlier answer.
@immutable
class AssistMessage {
  const AssistMessage.user(this.text) : fromModel = false;
  const AssistMessage.model(this.text) : fromModel = true;

  final String text;
  final bool fromModel;
}

/// A recording sent along with the words, for Transcribe.
@immutable
class AssistAudio {
  const AssistAudio({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Everything one assist call sends ([[ADR-013-Assist-Providers]]).
@immutable
class AssistRequest {
  const AssistRequest({
    required this.system,
    required this.messages,
    this.audio,
  });

  /// How to behave: the action's instructions.
  final String system;
  final List<AssistMessage> messages;
  final AssistAudio? audio;
}

/// Why an answer did not come.
enum AssistFailure {
  /// The key was refused, or there is none.
  badKey,

  /// Too many requests, or the quota is spent.
  quota,

  /// No connection.
  offline,

  /// The provider cannot do this (audio to a text-only model).
  unsupported,

  /// Anything else the provider said.
  other,
}

class AssistException implements Exception {
  const AssistException(this.failure, [this.detail]);

  final AssistFailure failure;

  /// The provider's own words, for "other"; never shown for the rest.
  final String? detail;

  @override
  String toString() =>
      'AssistException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// A model that answers ([[ADR-013-Assist-Providers]]). Every action is
/// a prompt over this one call; no screen knows which provider it is.
abstract interface class AssistProvider {
  /// The name the sheet shows: "what will be sent, and to whom" (N8).
  String get displayName;

  /// Whether it can take a recording (Transcribe).
  bool get acceptsAudio;

  /// The answer, as it arrives. Throws [AssistException].
  Stream<String> stream(AssistRequest request);
}
