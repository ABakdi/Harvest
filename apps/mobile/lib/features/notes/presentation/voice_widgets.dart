import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/voice_gateways.dart';
import 'package:harvest/features/notes/domain/voice.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:just_audio/just_audio.dart';

/// Records into [noteUuid] and returns the recording, or null when it
/// was discarded or the microphone was refused ([[Notes]] N7).
Future<NoteAttachment?> showRecordingSheet(
  BuildContext context, {
  required String noteUuid,
}) => showHarvestSheet<NoteAttachment>(
  context,
  builder: (_) => _RecordingSheet(noteUuid: noteUuid),
);

class _RecordingSheet extends ConsumerStatefulWidget {
  const _RecordingSheet({required this.noteUuid});

  final String noteUuid;

  @override
  ConsumerState<_RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends ConsumerState<_RecordingSheet> {
  late final VoiceRecorder _recorder = ref.read(voiceRecorderProvider);
  late final NoteAttachmentsRepository _attachments = ref.read(
    noteAttachmentsRepositoryProvider,
  );
  final _clock = Stopwatch();
  Timer? _tick;
  StreamSubscription<double>? _levels;
  double _level = 0;
  ({String relative, File file})? _slot;
  String? _fileName;
  var _refused = false;
  var _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final taken = await _attachments.takenNames();
    final name = voiceFileName(DateTime.now(), taken: taken);
    final slot = await _attachments.storage.reserve(widget.noteUuid, name);
    final ok = await _recorder.start(slot.file.path);
    if (!mounted) {
      if (ok) await _recorder.cancel();
      return;
    }
    if (!ok) {
      setState(() => _refused = true);
      return;
    }
    await HarvestHaptics.tick();
    _slot = slot;
    _fileName = name;
    _clock.start();
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
    _levels = _recorder.levels().listen((level) => _level = level);
  }

  Future<void> _stop() async {
    if (_done) return;
    _done = true;
    final navigator = Navigator.of(context);
    _clock.stop();
    _tick?.cancel();
    await _levels?.cancel();
    final path = await _recorder.stop();
    final slot = _slot;
    final name = _fileName;
    if (path == null || slot == null || name == null) {
      navigator.pop();
      return;
    }
    final size = slot.file.existsSync() ? slot.file.lengthSync() : 0;
    final attachment = await _attachments.add(
      noteUuid: widget.noteUuid,
      fileName: name,
      storedPath: slot.relative,
      sizeBytes: size,
      durationMs: _clock.elapsedMilliseconds,
    );
    await HarvestHaptics.thud();
    navigator.pop(attachment);
  }

  Future<void> _discard() async {
    _done = true;
    final navigator = Navigator.of(context);
    _tick?.cancel();
    await _levels?.cancel();
    await _recorder.cancel();
    final slot = _slot;
    if (slot != null) await _attachments.storage.delete(slot.relative);
    navigator.pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_levels?.cancel());
    // Dismissed by a swipe: nothing was chosen, so nothing is kept.
    if (!_done) {
      unawaited(_recorder.cancel());
      final slot = _slot;
      if (slot != null) unawaited(_attachments.storage.delete(slot.relative));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_refused) {
      return HarvestSheet(
        title: l10n.voiceRecord,
        children: [Text(l10n.voiceNoMic)],
      );
    }
    final elapsed = _clock.elapsed;
    return HarvestSheet(
      title: l10n.voiceRecording,
      children: [
        Center(
          child: Text(
            formatClock(elapsed),
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        LinearProgressIndicator(
          value: _level,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: scheme.error,
        ),
        const SizedBox(height: HarvestSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_discard()),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.voiceDiscard),
              ),
            ),
            const SizedBox(width: HarvestSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: _slot == null ? null : () => unawaited(_stop()),
                icon: const Icon(Icons.stop_rounded),
                label: Text(l10n.voiceStop),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = d.inMinutes;
  return '${two(minutes)}:${two(d.inSeconds % 60)}';
}

/// One recording, playable, under the note it belongs to.
class RecordingPlayer extends ConsumerStatefulWidget {
  const RecordingPlayer({
    required this.attachment,
    this.onTranscribe,
    super.key,
  });

  final NoteAttachment attachment;

  /// Offered when the assist can take audio ([[Notes]] N10).
  final VoidCallback? onTranscribe;

  @override
  ConsumerState<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends ConsumerState<RecordingPlayer> {
  final _player = AudioPlayer();
  var _missing = false;
  var _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final file = await ref
        .read(attachmentStorageProvider)
        .fileOf(widget.attachment.storedPath);
    if (!file.existsSync()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    await _player.setFilePath(file.path);
    _loaded = true;
  }

  Future<void> _toggle() async {
    await _ensureLoaded();
    if (_missing) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = widget.attachment.duration ?? Duration.zero;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HarvestSpacing.sm),
        child: StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, state) {
            final playing = state.data?.playing ?? false;
            return Row(
              children: [
                IconButton(
                  tooltip: playing ? l10n.voicePause : l10n.voicePlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: _missing ? null : () => unawaited(_toggle()),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                      if (_missing)
                        Text(
                          l10n.voiceMissing,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        )
                      else
                        StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          builder: (context, position) {
                            final at = position.data ?? Duration.zero;
                            final length = _player.duration ?? total;
                            final max = length.inMilliseconds.toDouble();
                            return Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: max <= 0
                                        ? 0
                                        : at.inMilliseconds
                                              .clamp(0, max)
                                              .toDouble(),
                                    max: max <= 0 ? 1 : max,
                                    onChanged: max <= 0
                                        ? null
                                        : (value) => unawaited(
                                            _player.seek(
                                              Duration(
                                                milliseconds: value.round(),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Text(
                                  formatClock(playing ? at : length),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                if (widget.onTranscribe != null && !_missing)
                  IconButton(
                    tooltip: l10n.voiceTranscribe,
                    icon: const Icon(Icons.subtitles_outlined),
                    onPressed: widget.onTranscribe,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reads [markdown] aloud, a paragraph at a time ([[Notes]] N10).
Future<void> showReadAloudSheet(
  BuildContext context, {
  required String markdown,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _ReadAloudSheet(markdown: markdown),
);

class _ReadAloudSheet extends ConsumerStatefulWidget {
  const _ReadAloudSheet({required this.markdown});

  final String markdown;

  @override
  ConsumerState<_ReadAloudSheet> createState() => _ReadAloudSheetState();
}

class _ReadAloudSheetState extends ConsumerState<_ReadAloudSheet> {
  late final Speaker _speaker = ref.read(speakerProvider);
  late final List<String> _paragraphs = speechParagraphs(widget.markdown);
  var _index = 0;
  var _playing = false;
  double _rate = 1;

  /// Bumped on every stop, so a paragraph that finishes after I pressed
  /// stop does not start the next one.
  var _run = 0;

  Future<void> _play() async {
    if (_paragraphs.isEmpty) return;
    final run = ++_run;
    setState(() => _playing = true);
    final fallback = Localizations.localeOf(context).languageCode;
    while (mounted && run == _run && _index < _paragraphs.length) {
      final text = _paragraphs[_index];
      await _speaker.speak(
        text,
        language: speechLanguageOf(text, fallback: fallback),
        rate: _rate,
      );
      if (!mounted || run != _run) return;
      setState(() => _index++);
    }
    if (mounted && run == _run) {
      setState(() {
        _playing = false;
        _index = 0;
      });
    }
  }

  Future<void> _pause() async {
    _run++;
    await _speaker.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _next() async {
    await _pause();
    if (_index < _paragraphs.length - 1) setState(() => _index++);
    await _play();
  }

  @override
  void dispose() {
    _run++;
    unawaited(_speaker.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_paragraphs.isEmpty) {
      return HarvestSheet(
        title: l10n.readAloud,
        children: [Text(l10n.readAloudEmpty)],
      );
    }
    return HarvestSheet(
      title: l10n.readAloud,
      children: [
        Text(
          l10n.readAloudParagraph(
            (_index + 1).clamp(1, _paragraphs.length),
            _paragraphs.length,
          ),
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Text(
          _paragraphs[_index.clamp(0, _paragraphs.length - 1)],
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: HarvestSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              tooltip: _playing ? l10n.voicePause : l10n.voicePlay,
              iconSize: 32,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              onPressed: () => unawaited(_playing ? _pause() : _play()),
            ),
            const SizedBox(width: HarvestSpacing.md),
            IconButton(
              tooltip: l10n.readAloudNext,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: () => unawaited(_next()),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Text(l10n.readAloudSpeed, style: theme.textTheme.labelMedium),
        Slider(
          value: _rate,
          min: 0.75,
          max: 2,
          divisions: 5,
          label: '${_rate.toStringAsFixed(2)}×',
          onChanged: (value) => setState(() => _rate = value),
        ),
      ],
    );
  }
}
