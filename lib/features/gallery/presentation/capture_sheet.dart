import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gallery/data/camera_gateway.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Adds a memory to [album]: four ways in, and a note to go with it.
///
/// The note is written *before* the shutter rather than after, because
/// what I was trying is the thing I forget by the time the picture is
/// filed.
Future<Memory?> showCaptureSheet(
  BuildContext context, {
  required Album album,
}) => showHarvestSheet<Memory>(
  context,
  builder: (_) => _CaptureSheet(album: album),
);

class _CaptureSheet extends ConsumerStatefulWidget {
  const _CaptureSheet({required this.album});

  final Album album;

  @override
  ConsumerState<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<_CaptureSheet> {
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _capture({
    required CaptureSource source,
    required bool video,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final note = _note.text.trim();

    final memory = await ref
        .read(galleryServiceProvider)
        .capture(
          album: widget.album,
          source: source,
          camera: ref.read(cameraGatewayProvider),
          video: video,
          note: note.isEmpty ? null : note,
        );

    if (!mounted) return;
    if (memory == null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.galleryNoCapture)));
      return;
    }
    await HarvestHaptics.thud();
    navigator.pop(memory);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.galleryAddTo(widget.album.name),
      subtitle: widget.album.isScheduled ? l10n.galleryCheckInHint : null,
      children: [
        TextField(
          controller: _note,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: l10n.galleryMemoryNote,
            hintText: l10n.galleryMemoryNoteHint,
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(HarvestSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: HarvestSpacing.sm,
            runSpacing: HarvestSpacing.sm,
            children: [
              _CaptureButton(
                icon: Icons.photo_camera,
                label: l10n.galleryTakePhoto,
                primary: true,
                onPressed: () => _capture(
                  source: CaptureSource.camera,
                  video: false,
                ),
              ),
              _CaptureButton(
                icon: Icons.photo_library_outlined,
                label: l10n.galleryPickPhoto,
                onPressed: () => _capture(
                  source: CaptureSource.library,
                  video: false,
                ),
              ),
              _CaptureButton(
                icon: Icons.videocam,
                label: l10n.galleryTakeVideo,
                onPressed: () => _capture(
                  source: CaptureSource.camera,
                  video: true,
                ),
              ),
              _CaptureButton(
                icon: Icons.video_library_outlined,
                label: l10n.galleryPickVideo,
                onPressed: () => _capture(
                  source: CaptureSource.library,
                  video: true,
                ),
              ),
            ],
          ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 20), const SizedBox(width: 6), Text(label)],
    );
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - HarvestSpacing.lg * 2 - 12) / 2,
      child: primary
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}
