import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:harvest/features/assist/domain/assist.dart';
import 'package:http/http.dart' as http;

/// Gemini, on the Generative Language API, with my own key
/// ([[ADR-013-Assist-Providers]]). The key goes in a header, never the
/// URL, so it cannot end up in a log line or a proxy's history.
class GeminiProvider implements AssistProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const defaultModel = 'gemini-2.5-flash';

  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  String get displayName => 'Gemini ($model)';

  @override
  bool get acceptsAudio => true;

  @override
  Stream<String> stream(AssistRequest request) async* {
    // Built whole rather than resolved against a base: in
    // `gemini-2.5-flash:stream…` the part before the colon would parse
    // as a URL scheme.
    final url = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:streamGenerateContent',
      {'alt': 'sse'},
    );
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': request.system},
        ],
      },
      'contents': [
        for (final (i, message) in request.messages.indexed)
          {
            'role': message.fromModel ? 'model' : 'user',
            'parts': [
              {'text': message.text},
              if (i == request.messages.length - 1 && request.audio != null)
                {
                  'inlineData': {
                    'mimeType': request.audio!.mimeType,
                    'data': base64Encode(request.audio!.bytes),
                  },
                },
            ],
          },
      ],
    };
    final lines = await _post(
      _client,
      url,
      headers: {'x-goog-api-key': apiKey, 'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    await for (final data in lines) {
      final json = jsonDecode(data);
      if (json is! Map<String, Object?>) continue;
      for (final candidate in (json['candidates'] as List<Object?>?) ?? []) {
        final content = (candidate as Map<String, Object?>?)?['content'];
        final parts = (content as Map<String, Object?>?)?['parts'];
        for (final part in (parts as List<Object?>?) ?? []) {
          final text = (part as Map<String, Object?>?)?['text'];
          if (text is String && text.isNotEmpty) yield text;
        }
      }
    }
  }
}

/// Anything that speaks `/v1/chat/completions`: OpenAI, OpenRouter, a
/// local Ollama. Text only.
class OpenAiCompatibleProvider implements AssistProvider {
  OpenAiCompatibleProvider({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;

  /// Up to and including `/v1`, e.g. `https://api.openai.com/v1`.
  final String baseUrl;
  final http.Client _client;

  @override
  String get displayName =>
      '$model (${Uri.tryParse(baseUrl)?.host ?? baseUrl})';

  @override
  bool get acceptsAudio => false;

  @override
  Stream<String> stream(AssistRequest request) async* {
    if (request.audio != null) {
      throw const AssistException(AssistFailure.unsupported);
    }
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final lines = await _post(
      _client,
      Uri.parse(base).resolve('chat/completions'),
      headers: {
        if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': request.system},
          for (final message in request.messages)
            {
              'role': message.fromModel ? 'assistant' : 'user',
              'content': message.text,
            },
        ],
      }),
    );
    await for (final data in lines) {
      if (data == '[DONE]') return;
      final json = jsonDecode(data);
      if (json is! Map<String, Object?>) continue;
      for (final choice in (json['choices'] as List<Object?>?) ?? []) {
        final delta = (choice as Map<String, Object?>?)?['delta'];
        final text = (delta as Map<String, Object?>?)?['content'];
        if (text is String && text.isNotEmpty) yield text;
      }
    }
  }
}

/// Posts and hands back the server-sent events' `data:` payloads, or
/// throws the failure in plain terms ([[Notes]]: errors are words in
/// the sheet, never an exception on the note).
Future<Stream<String>> _post(
  http.Client client,
  Uri url, {
  required Map<String, String> headers,
  required String body,
}) async {
  final request = http.Request('POST', url)
    ..headers.addAll(headers)
    ..body = body;
  final http.StreamedResponse response;
  try {
    response = await client.send(request).timeout(const Duration(seconds: 30));
  } on SocketException {
    throw const AssistException(AssistFailure.offline);
  } on TimeoutException {
    throw const AssistException(AssistFailure.offline);
  } on http.ClientException {
    throw const AssistException(AssistFailure.offline);
  }
  if (response.statusCode != 200) {
    final text = await response.stream.bytesToString().catchError((_) => '');
    throw AssistException(
      switch (response.statusCode) {
        400 when text.contains('API_KEY') => AssistFailure.badKey,
        401 || 403 => AssistFailure.badKey,
        429 => AssistFailure.quota,
        _ => AssistFailure.other,
      },
      _message(text) ?? 'HTTP ${response.statusCode}',
    );
  }
  return response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .where((data) => data.isNotEmpty);
}

/// The provider's own error message, if its body has one.
String? _message(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map<String, Object?>) {
      final error = json['error'];
      if (error is Map<String, Object?> && error['message'] is String) {
        return error['message']! as String;
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}
