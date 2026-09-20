import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/assist/data/providers.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/assist/domain/prompts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Phase 5, M5.6: the assist behind one interface
/// ([[ADR-013-Assist-Providers]]).
void main() {
  http.StreamedResponse sse(List<String> events, {int status = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(events.map((e) => 'data: $e\n\n').join())),
        status,
      );

  group('Gemini', () {
    test(
      'streams the parts, with the key in a header and not the URL',
      () async {
        late http.BaseRequest seen;
        String? sentBody;
        final client = MockClient.streaming((request, body) async {
          seen = request;
          sentBody = await body.bytesToString();
          return sse([
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Slept '},
                    ],
                  },
                },
              ],
            }),
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'early.'},
                    ],
                  },
                },
              ],
            }),
          ]);
        });
        final gemini = GeminiProvider(apiKey: 'k-123', client: client);
        final answer = await gemini
            .stream(buildRequest(AssistAction.summarise, text: 'A long note'))
            .join();

        expect(answer, 'Slept early.');
        expect(seen.headers['x-goog-api-key'], 'k-123');
        expect(seen.url.toString(), isNot(contains('k-123')));
        expect(
          seen.url.path,
          endsWith('gemini-2.5-flash:streamGenerateContent'),
        );
        expect(sentBody, contains('A long note'));
      },
    );

    test('sends a recording inline for Transcribe', () async {
      String? sentBody;
      final client = MockClient.streaming((request, body) async {
        sentBody = await body.bytesToString();
        return sse([]);
      });
      await GeminiProvider(apiKey: 'k', client: client)
          .stream(
            buildRequest(
              AssistAction.transcribe,
              text: '',
              audio: AssistAudio(
                bytes: Uint8List.fromList([1, 2, 3]),
                mimeType: 'audio/mp4',
              ),
            ),
          )
          .drain<void>();
      final json = jsonDecode(sentBody!) as Map<String, Object?>;
      final parts =
          ((json['contents']! as List).single as Map)['parts'] as List;
      expect(parts.last, {
        'inlineData': {
          'mimeType': 'audio/mp4',
          'data': base64Encode([1, 2, 3]),
        },
      });
    });

    test('a refused key and a spent quota come back in plain terms', () async {
      Future<AssistFailure> failureFor(int status, String body) async {
        final client = MockClient.streaming(
          (request, _) async => http.StreamedResponse(
            Stream.value(utf8.encode(body)),
            status,
          ),
        );
        try {
          await GeminiProvider(apiKey: 'k', client: client)
              .stream(buildRequest(AssistAction.summarise, text: 'x'))
              .drain<void>();
        } on AssistException catch (error) {
          return error.failure;
        }
        fail('no error');
      }

      expect(
        await failureFor(400, '{"error":{"message":"API_KEY_INVALID"}}'),
        AssistFailure.badKey,
      );
      expect(await failureFor(429, '{}'), AssistFailure.quota);
      expect(await failureFor(500, 'oops'), AssistFailure.other);
    });
  });

  group('OpenAI-compatible', () {
    test('streams deltas until [DONE], and refuses audio', () async {
      final client = MockClient.streaming(
        (request, _) async => sse([
          jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Hel'},
              },
            ],
          }),
          jsonEncode({
            'choices': [
              {
                'delta': {'content': 'lo'},
              },
            ],
          }),
          '[DONE]',
        ]),
      );
      final provider = OpenAiCompatibleProvider(
        apiKey: 'k',
        model: 'gpt-4o-mini',
        baseUrl: 'https://api.example.org/v1',
        client: client,
      );
      expect(
        await provider
            .stream(buildRequest(AssistAction.rewrite, text: 'x'))
            .join(),
        'Hello',
      );
      expect(
        () => provider
            .stream(
              buildRequest(
                AssistAction.transcribe,
                text: '',
                audio: AssistAudio(bytes: Uint8List(1), mimeType: 'audio/mp4'),
              ),
            )
            .drain<void>(),
        throwsA(isA<AssistException>()),
      );
    });
  });

  test('every action sends only what it names (N8)', () {
    final continueRequest = buildRequest(
      AssistAction.continueWriting,
      text: 'the whole note, which must not be sent',
      upToCaret: 'up to here',
    );
    expect(continueRequest.messages.single.text, 'up to here');

    final ask = buildRequest(
      AssistAction.ask,
      text: 'note body',
      question: 'when?',
      language: 'ar',
    );
    expect(ask.messages.single.text, contains('note body'));
    expect(ask.messages.single.text, contains('when?'));
    expect(ask.system, contains('Arabic'));
  });

  group('the Harvest server', () {
    HarvestServerProvider serverWith(http.Client client, {String? token}) =>
        HarvestServerProvider(
          baseUrl: Uri.parse('https://harvest.example.org'),
          accessToken: () async => token,
          model: 'gemini-2.5-flash',
          client: client,
        );

    test("sends the turns to /v1/assist with the account's token", () async {
      late http.BaseRequest seen;
      String? sentBody;
      final client = MockClient.streaming((request, body) async {
        seen = request;
        sentBody = await body.bytesToString();
        return sse([
          jsonEncode({'text': 'A note '}),
          jsonEncode({'text': 'about bread.'}),
          '[DONE]',
        ]);
      });

      final words = await serverWith(client, token: 'an-access-token')
          .stream(
            const AssistRequest(
              system: 'Be brief.',
              messages: [AssistMessage.user('Summarise this note.')],
            ),
          )
          .join();

      expect(words, 'A note about bread.');
      expect(seen.url.path, '/v1/assist');
      expect(seen.headers['authorization'], 'Bearer an-access-token');
      final sent = jsonDecode(sentBody!) as Map<String, Object?>;
      expect(sent['system'], 'Be brief.');
      expect((sent['messages']! as List).single, {
        'role': 'user',
        'text': 'Summarise this note.',
      });
    });

    test('carries a recording, which the server model can hear', () async {
      String? sentBody;
      final client = MockClient.streaming((request, body) async {
        sentBody = await body.bytesToString();
        return sse([
          jsonEncode({'text': 'Buy bread.'}),
          '[DONE]',
        ]);
      });

      final provider = serverWith(client, token: 'token');
      expect(provider.acceptsAudio, isTrue);
      await provider
          .stream(
            AssistRequest(
              system: 'Transcribe.',
              messages: const [AssistMessage.user('')],
              audio: AssistAudio(
                bytes: Uint8List.fromList([1, 2, 3]),
                mimeType: 'audio/mp4',
              ),
            ),
          )
          .join();

      final sent = jsonDecode(sentBody!) as Map<String, Object?>;
      expect((sent['audio']! as Map)['mimeType'], 'audio/mp4');
      expect((sent['audio']! as Map)['data'], base64Encode([1, 2, 3]));
    });

    test('turns a failure sent mid-answer into the right kind', () async {
      final client = MockClient.streaming(
        (request, body) async => sse([
          jsonEncode({'text': 'Half '}),
          jsonEncode({'error': 'rate_limited'}),
        ]),
      );

      final stream = serverWith(client, token: 'token').stream(
        const AssistRequest(
          system: 'Be brief.',
          messages: [AssistMessage.user('Again.')],
        ),
      );
      expect(
        stream,
        emitsInOrder([
          'Half ',
          emitsError(
            isA<AssistException>().having(
              (e) => e.failure,
              'failure',
              AssistFailure.quota,
            ),
          ),
        ]),
      );
    });

    test('without a session there is nothing to send', () async {
      final client = MockClient.streaming(
        (request, body) async => sse([
          jsonEncode({'text': 'never'}),
        ]),
      );
      expect(
        serverWith(client).stream(
          const AssistRequest(
            system: 'Be brief.',
            messages: [AssistMessage.user('Hello.')],
          ),
        ),
        emitsError(isA<AssistException>()),
      );
    });
  });
}
