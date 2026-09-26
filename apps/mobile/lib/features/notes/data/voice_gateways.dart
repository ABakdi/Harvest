import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_to_text.dart';

part 'voice_gateways.g.dart';

/// The microphone, for recordings ([[Notes]] N7). A fake in tests.
abstract interface class VoiceRecorder {
  /// Asks for the microphone if it has not been granted yet.
  Future<bool> ensurePermission();

  /// Starts recording AAC to [path]. False when the phone refused.
  Future<bool> start(String path);

  /// Stops and returns the file's path, or null when nothing was kept.
  Future<String?> stop();

  /// Throws the take away.
  Future<void> cancel();

  /// Loudness, 0 (silence) to 1, a few times a second while recording.
  Stream<double> levels();
}

class RecordPackageRecorder implements VoiceRecorder {
  RecordPackageRecorder();

  final _recorder = AudioRecorder();

  @override
  Future<bool> ensurePermission() async {
    try {
      return await _recorder.hasPermission();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> start(String path) async {
    try {
      if (!await _recorder.hasPermission()) return false;
      // Mono AAC at 64 kbps: about half a megabyte a minute, and plenty
      // for a voice. Music this is not.
      await _recorder.start(
        const RecordConfig(bitRate: 64000, numChannels: 1),
        path: path,
      );
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } on PlatformException {
      return;
    }
  }

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      // dBFS: 0 is the loudest, -45 or so is a quiet room.
      .map((amplitude) => ((amplitude.current + 45) / 45).clamp(0.0, 1.0));
}

/// Speech to text at the caret, on the phone's own recogniser (N10).
abstract interface class Dictation {
  Future<bool> available();

  /// Listens until [stop], sending the words heard so far, then the
  /// final words with `done` set.
  Future<void> listen({
    required String localeId,
    required void Function(String words, {required bool done}) onWords,
  });

  Future<void> stop();
}

class PhoneDictation implements Dictation {
  PhoneDictation();

  final _speech = SpeechToText();
  var _ready = false;

  @override
  Future<bool> available() async {
    if (_ready) return true;
    try {
      return _ready = await _speech.initialize();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, {required bool done}) onWords,
  }) async {
    if (!await available()) return;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) =>
          onWords(result.recognizedWords, done: result.finalResult),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}

/// Text to speech, on the phone's own engine (N10).
abstract interface class Speaker {
  /// Speaks [text] in [language] at [rate] (1 is normal) and completes
  /// when it has been said, or [stop] was called.
  Future<void> speak(String text, {required String language, double rate});

  Future<void> stop();
}

class PhoneSpeaker implements Speaker {
  PhoneSpeaker() {
    unawaited(_tts.awaitSpeakCompletion(true));
  }

  final _tts = FlutterTts();

  @override
  Future<void> speak(
    String text, {
    required String language,
    double rate = 1,
  }) async {
    try {
      await _tts.setLanguage(language);
      // The engine's 0.5 is a normal pace; its scale runs 0 to 1.
      await _tts.setSpeechRate((rate / 2).clamp(0.1, 1.0));
      await _tts.speak(text);
    } on PlatformException {
      return;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on PlatformException {
      return;
    }
  }
}

@Riverpod(keepAlive: true)
VoiceRecorder voiceRecorder(Ref ref) => RecordPackageRecorder();

@Riverpod(keepAlive: true)
Dictation dictation(Ref ref) => PhoneDictation();

@Riverpod(keepAlive: true)
Speaker speaker(Ref ref) => PhoneSpeaker();
