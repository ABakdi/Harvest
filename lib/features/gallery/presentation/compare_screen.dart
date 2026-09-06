import 'package:flutter/material.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Two memories, side by side.
///
/// Defaults to the oldest and the newest, because that is the question
/// the album is usually asking. Either side can be moved along the run
/// with the strip under it.
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    required this.album,
    required this.memories,
    super.key,
  });

  final Album album;

  /// Newest first, the order the album grid uses.
  final List<Memory> memories;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late int _left = widget.memories.length - 1;
  var _right = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memories = widget.memories;
    if (memories.length < 2) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        title: Text(l10n.galleryCompare),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _side(memories[_left])),
                  const SizedBox(width: 2),
                  Expanded(child: _side(memories[_right])),
                ],
              ),
            ),
            _strip(
              label: l10n.galleryCompareLeft,
              selected: _left,
              onPick: (index) => setState(() => _left = index),
            ),
            _strip(
              label: l10n.galleryCompareRight,
              selected: _right,
              onPick: (index) => setState(() => _right = index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(Memory memory) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        MemoryView(memory: memory),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black.withValues(alpha: 0.5),
            child: Text(
              formatDay(context, memory.day),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _strip({
    required String label,
    required int selected,
    required ValueChanged<int> onPick,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: HarvestSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: HarvestSpacing.md,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.sm,
                vertical: 4,
              ),
              itemCount: widget.memories.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => onPick(index),
                  child: Container(
                    width: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(HarvestRadii.chip),
                      border: Border.all(
                        color: index == selected
                            ? theme.colorScheme.secondary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: MemoryView(
                      memory: widget.memories[index],
                      borderRadius: BorderRadius.circular(HarvestRadii.chip),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
