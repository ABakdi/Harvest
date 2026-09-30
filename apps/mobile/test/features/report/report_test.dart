import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/domain/heartbeat.dart';
import 'package:harvest/features/gallery/data/camera_gateway.dart';
import 'package:harvest/features/report/domain/report.dart';
import 'package:harvest/features/report/presentation/report_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import '../../support/fake_camera.dart';
import '../../support/memory_secrets.dart';

/// The JPEG segment markers before the image data: what travels beside
/// the pixels.
List<int> _segments(Uint8List jpeg) {
  final markers = <int>[];
  var at = 2; // past SOI
  while (at + 4 <= jpeg.length && jpeg[at] == 0xFF) {
    final marker = jpeg[at + 1];
    markers.add(marker);
    if (marker == 0xDA) break; // start of scan: the pixels follow
    final length = (jpeg[at + 2] << 8) | jpeg[at + 3];
    at += 2 + length;
  }
  return markers;
}

/// A photo as a phone takes one: its camera and where it was, in EXIF.
Uint8List _photoWithGps({int width = 3000, int height = 1000}) {
  final photo = img.Image(width: width, height: height)
    ..exif.imageIfd['Make'] = 'SecretCam'
    ..exif.gpsIfd[1] = img.IfdValueAscii('N')
    ..exif.gpsIfd[3] = img.IfdValueAscii('E');
  img.fill(photo, color: img.ColorRgb8(40, 160, 90));
  return img.encodeJpg(photo);
}

ApiClient _client(http.Client http, {String? access}) {
  final tokens = TokenStore(MemorySecrets())..access = access;
  return ApiClient(
    baseUrl: () => Uri.parse('https://harvest.test'),
    tokens: tokens,
    client: http,
  );
}

void main() {
  group('what a report may carry (Admin F12-5)', () {
    Uint8List bytes(int n) => Uint8List(n);

    test('words are needed, and no more than five thousand', () {
      expect(
        reportProblem(text: '   ', images: const [], audioBytes: null),
        ReportProblem.empty,
      );
      expect(
        reportProblem(text: 'x' * 5001, images: const [], audioBytes: null),
        ReportProblem.tooLong,
      );
      expect(
        reportProblem(text: 'It froze', images: const [], audioBytes: null),
        isNull,
      );
    });

    test('four pictures, one recording, twenty-one megabytes all told', () {
      expect(
        reportProblem(
          text: 'x',
          images: List.generate(5, (_) => bytes(10)),
          audioBytes: null,
        ),
        ReportProblem.tooManyImages,
      );
      expect(
        reportProblem(
          text: 'x',
          images: [bytes(ReportLimits.imageBytes + 1)],
          audioBytes: null,
        ),
        ReportProblem.imageTooLarge,
      );
      expect(
        reportProblem(
          text: 'x',
          images: const [],
          audioBytes: ReportLimits.audioBytes + 1,
        ),
        ReportProblem.audioTooLarge,
      );
      expect(
        reportProblem(
          text: 'x',
          images: List.generate(4, (_) => bytes(ReportLimits.imageBytes)),
          audioBytes: ReportLimits.audioBytes,
        ),
        ReportProblem.tooLarge,
      );
    });
  });

  group('a picture made fit to leave (AD7)', () {
    test('keeps its pixels and loses its EXIF, GPS and camera', () {
      final original = _photoWithGps();
      // The photo as taken does carry them.
      expect(_segments(original), contains(0xE1));
      expect(
        latin1.decode(original, allowInvalid: true),
        contains('SecretCam'),
      );

      final sent = reencodeForReport(original)!;
      expect(_segments(sent), isNot(contains(0xE1)));
      expect(latin1.decode(sent, allowInvalid: true), isNot(contains('Exif')));
      expect(
        latin1.decode(sent, allowInvalid: true),
        isNot(contains('SecretCam')),
      );
      final decoded = img.decodeJpg(sent)!;
      expect(decoded.width, ReportLimits.maxEdge);
      expect(decoded.height, closeTo(683, 1));
    });

    test(
      'a small picture keeps its size, and a file that is not one is refused',
      () {
        final small = reencodeForReport(
          _photoWithGps(width: 300, height: 400),
        )!;
        expect(img.decodeJpg(small)!.width, 300);
        expect(_segments(small), isNot(contains(0xE1)));
        expect(
          reencodeForReport(Uint8List.fromList(utf8.encode('no'))),
          isNull,
        );
      },
    );
  });

  group('sending', () {
    test('goes without the session, even signed in, with every part', () async {
      late http.Request sent;
      final api = _client(
        MockClient((request) async {
          sent = request;
          return http.Response('{"id":"abc"}', 201);
        }),
        access: 'a-token',
      );
      final folder = await Directory.systemTemp.createTemp('report');
      addTearDown(() => folder.delete(recursive: true));
      final voice = File('${folder.path}/v.m4a')..writeAsBytesSync([1, 2, 3]);

      final id = await ReportSender(api: api, version: () async => '3.3.0')
          .send(
            text: '  The keyboard hides the button  ',
            images: [
              Uint8List.fromList([9, 9]),
            ],
            recording: voice,
          );

      expect(id, 'abc');
      expect(sent.url.path, '/v1/reports');
      expect(
        sent.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect(body['text'], 'The keyboard hides the button');
      expect(body['platform'], 'android');
      expect(body['appVersion'], '3.3.0');
      expect(body['attachments'], [
        {
          'kind': 'image',
          'type': 'image/jpeg',
          'data': base64Encode([9, 9]),
        },
        {
          'kind': 'audio',
          'type': 'audio/mp4',
          'data': base64Encode([1, 2, 3]),
        },
      ]);
    });
  });

  group('the screen', () {
    late Directory folder;
    setUp(() async => folder = await Directory.systemTemp.createTemp('report'));
    tearDown(() => folder.delete(recursive: true));

    Future<AppLocalizations> pump(
      WidgetTester tester, {
      required http.Client http,
      CameraGateway camera = const FakeCamera(),
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_client(http)),
            appVersionProvider.overrideWith((ref) async => '3.3.0'),
            cameraGatewayProvider.overrideWithValue(camera),
            reportTemporaryFolderProvider.overrideWithValue(() async => folder),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(ReportScreen)));
    }

    testWidgets('says what sending means, asks for words, then sends a '
        'picture without its metadata and goes back', (tester) async {
      final requests = <http.Request>[];
      final photo = File('${folder.path}/picked.jpg')
        ..writeAsBytesSync(_photoWithGps(width: 400, height: 300));
      final l10n = await pump(
        tester,
        http: MockClient((request) async {
          requests.add(request);
          return http.Response('{"id":"r1"}', 201);
        }),
        camera: FakeCamera(photo: photo),
      );
      expect(find.text(l10n.reportPrivacy), findsOneWidget);
      expect(find.text(l10n.reportPicturesNote), findsOneWidget);

      await tester.tap(find.text(l10n.reportSend));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportEmpty), findsOneWidget);
      expect(requests, isEmpty);

      await tester.enterText(find.byType(TextField), 'The chart is empty');
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.reportPickPhoto));
        // The re-encode runs off the UI isolate.
        for (var i = 0; i < 50 && find.byType(Image).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      // The picker's copy is let go once re-encoded.
      expect(photo.existsSync(), isFalse);

      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.reportSend));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      final attachment = (body['attachments']! as List).single as Map;
      final picture = base64Decode(attachment['data'] as String);
      expect(_segments(picture), isNot(contains(0xE1)));
      expect(find.byType(ReportScreen), findsNothing);
      expect(find.text(l10n.reportSent), findsOneWidget);
    });

    testWidgets('says how long to wait when the server is busy, and keeps '
        'the words', (tester) async {
      final l10n = await pump(
        tester,
        http: MockClient(
          (request) async => http.Response(
            '{"error":{"code":"rate_limited","message":"slow down"}}',
            429,
            headers: {'retry-after': '1800'},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'It crashed');
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.reportSend));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportLimited(30)), findsOneWidget);
      expect(find.text('It crashed'), findsOneWidget);
      expect(find.byType(ReportScreen), findsOneWidget);
    });

    testWidgets('says so when too large or offline', (tester) async {
      var answer = 413;
      final l10n = await pump(
        tester,
        http: MockClient((request) async {
          if (answer == 0) throw const SocketException('down');
          return http.Response('<html>too large</html>', answer);
        }),
      );
      await tester.enterText(find.byType(TextField), 'Big');
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.reportSend));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportTooLarge), findsOneWidget);

      answer = 0;
      await tester.runAsync(() async {
        await tester.tap(find.text(l10n.reportSend));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportOffline), findsOneWidget);
    });
  });
}
