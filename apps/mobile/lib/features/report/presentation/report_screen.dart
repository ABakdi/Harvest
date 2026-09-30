import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/gallery/data/camera_gateway.dart';
import 'package:harvest/features/gallery/domain/gallery.dart' show formatBytes;
import 'package:harvest/features/notes/data/voice_gateways.dart';
import 'package:harvest/features/report/domain/report.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a report's recording is made, until it is sent or given up.
typedef TemporaryFolder = Future<Directory> Function();

final reportTemporaryFolderProvider = Provider<TemporaryFolder>(
  (ref) => getTemporaryDirectory,
);

/// *Report a problem* ([[Admin]], F12-5): words, up to four pictures and
/// one voice note, sent to Harvest's team without the account (AD7).
///
/// A page of its own rather than a sheet: the words can run long, and
/// the keyboard must never cover them ([[Checkpoint-12]] B12-01).
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _text = TextEditingController();

  /// Each picture already re-encoded, with nothing but its pixels.
  final _images = <Uint8List>[];

  File? _recording;
  var _recordingBytes = 0;
  var _recordingNow = false;
  Timer? _recordLimit;
  AudioPlayer? _player;

  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _recordLimit?.cancel();
    if (_recordingNow) unawaited(ref.read(voiceRecorderProvider).cancel());
    unawaited(_player?.dispose());
    // What was recorded goes with the page, sent or not.
    unawaited(_deleteRecording(_recording));
    super.dispose();
  }

  Future<void> _deleteRecording(File? file) async {
    if (file == null) return;
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('[report] recording left behind: ${error.osError?.message}');
    }
  }

  Future<void> _addPicture({required bool camera}) async {
    final l10n = AppLocalizations.of(context);
    if (_images.length >= ReportLimits.images) {
      setState(() => _error = l10n.reportTooManyImages);
      return;
    }
    final gateway = ref.read(cameraGatewayProvider);
    final capture = await (camera ? gateway.takePhoto() : gateway.pickPhoto());
    if (capture == null) return;
    final encoded = await reencodeFileForReport(capture.file);
    // The picker's copy is ours to let go; the picture stays in the gallery.
    try {
      await capture.file.delete();
    } on FileSystemException {
      // Already gone.
    }
    if (!mounted) return;
    setState(() {
      if (encoded == null) {
        _error = l10n.reportNotAPicture;
      } else if (encoded.length > ReportLimits.imageBytes) {
        _error = l10n.reportImageTooLarge;
      } else {
        _images.add(encoded);
        _error = null;
      }
    });
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(voiceRecorderProvider);
    if (_recordingNow) {
      await _stopRecording();
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (!await recorder.ensurePermission()) {
      if (mounted) setState(() => _error = l10n.reportNoMic);
      return;
    }
    final folder = await ref.read(reportTemporaryFolderProvider)();
    final path = p.join(
      folder.path,
      'report-${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    if (!await recorder.start(path)) {
      if (mounted) setState(() => _error = l10n.reportNoMic);
      return;
    }
    // A few minutes at most: the recording stops on its own.
    _recordLimit = Timer(ReportLimits.recording, () {
      unawaited(_stopRecording());
    });
    if (mounted) setState(() => _recordingNow = true);
  }

  Future<void> _stopRecording() async {
    _recordLimit?.cancel();
    final path = await ref.read(voiceRecorderProvider).stop();
    if (!mounted) return;
    final file = path == null ? null : File(path);
    setState(() {
      _recordingNow = false;
      _recording = file != null && file.existsSync() ? file : null;
      _recordingBytes = _recording?.lengthSync() ?? 0;
    });
  }

  Future<void> _removeRecording() async {
    await _player?.stop();
    final old = _recording;
    setState(() {
      _recording = null;
      _recordingBytes = 0;
    });
    await _deleteRecording(old);
  }

  Future<void> _play() async {
    final recording = _recording;
    if (recording == null) return;
    final player = _player ??= AudioPlayer();
    if (player.playing) {
      await player.pause();
      return;
    }
    try {
      await player.setFilePath(recording.path);
      await player.seek(Duration.zero);
      unawaited(player.play());
    } on Object catch (error) {
      debugPrint('[report] cannot play: ${error.runtimeType}');
    }
  }

  String? _problemText(AppLocalizations l10n, ReportProblem problem) =>
      switch (problem) {
        ReportProblem.empty => l10n.reportEmpty,
        ReportProblem.tooLong => l10n.reportTextTooLong,
        ReportProblem.tooManyImages => l10n.reportTooManyImages,
        ReportProblem.imageTooLarge => l10n.reportImageTooLarge,
        ReportProblem.audioTooLarge => l10n.reportAudioTooLarge,
        ReportProblem.tooLarge => l10n.reportTooLarge,
      };

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_recordingNow) await _stopRecording();
    final problem = reportProblem(
      text: _text.text,
      images: _images,
      audioBytes: _recording == null ? null : _recordingBytes,
    );
    if (problem != null) {
      setState(() => _error = _problemText(l10n, problem));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(reportSenderProvider)
          .send(text: _text.text, images: _images, recording: _recording);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      await _removeRecording();
      _text.clear();
      _images.clear();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.reportSent)));
      if (mounted) Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error) {
          ApiException(offline: true) => l10n.reportOffline,
          ApiException(status: 429, :final retryAfter) => l10n.reportLimited(
            ((retryAfter?.inSeconds ?? 60) / 60).ceil().clamp(1, 1440),
          ),
          ApiException(status: 413) => l10n.reportTooLarge,
          _ => l10n.reportFailed,
        };
      });
    } on Object catch (error) {
      debugPrint('[report] failed: ${error.runtimeType}');
      if (mounted) setState(() => _error = l10n.reportFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final full = _images.length >= ReportLimits.images;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(HarvestSpacing.md),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(
                    controller: _text,
                    minLines: 6,
                    maxLines: 14,
                    maxLength: ReportLimits.textMax,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      labelText: l10n.reportTextLabel,
                      hintText: l10n.reportTextHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: HarvestSpacing.md),
                  if (_images.isNotEmpty)
                    Wrap(
                      spacing: HarvestSpacing.sm,
                      runSpacing: HarvestSpacing.sm,
                      children: [
                        for (final (index, image) in _images.indexed)
                          _Thumbnail(
                            bytes: image,
                            label: formatBytes(image.length),
                            removeLabel: l10n.reportRemove,
                            onRemove: _sending
                                ? null
                                : () => setState(() => _images.removeAt(index)),
                          ),
                      ],
                    ),
                  Wrap(
                    spacing: HarvestSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sending || full
                            ? null
                            : () => unawaited(_addPicture(camera: true)),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.reportTakePhoto),
                      ),
                      OutlinedButton.icon(
                        onPressed: _sending || full
                            ? null
                            : () => unawaited(_addPicture(camera: false)),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.reportPickPhoto),
                      ),
                    ],
                  ),
                  Text(l10n.reportPicturesNote, style: muted),
                  const SizedBox(height: HarvestSpacing.md),
                  if (_recording == null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonalIcon(
                        onPressed: _sending
                            ? null
                            : () => unawaited(_toggleRecording()),
                        icon: Icon(
                          _recordingNow
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                        ),
                        label: Text(
                          _recordingNow
                              ? l10n.reportStopRecording
                              : l10n.reportRecord,
                        ),
                      ),
                    )
                  else
                    Card(
                      child: ListTile(
                        leading: IconButton(
                          tooltip: l10n.voicePlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: () => unawaited(_play()),
                        ),
                        title: Text(l10n.reportRecordingLabel),
                        subtitle: Text(formatBytes(_recordingBytes)),
                        trailing: IconButton(
                          tooltip: l10n.reportRemove,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _sending
                              ? null
                              : () => unawaited(_removeRecording()),
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: HarvestSpacing.md),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // At the foot, above the keyboard: what sending means, and
            // the button, never scrolled away (B12-01).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.sm,
                HarvestSpacing.md,
                HarvestSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.reportPrivacy, style: muted),
                  const SizedBox(height: HarvestSpacing.sm),
                  FilledButton.icon(
                    onPressed: _sending ? null : () => unawaited(_send()),
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending ? l10n.reportSending : l10n.reportSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.bytes,
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  final Uint8List bytes;
  final String label;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HarvestRadii.chip),
              child: Image.memory(
                bytes,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                cacheWidth: 192,
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                tooltip: removeLabel,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
