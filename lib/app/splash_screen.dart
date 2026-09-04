import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/growing_tree.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// How long the tree takes to go from bare soil to fruit.
const splashGrowth = Duration(milliseconds: 1700);

/// The first thing the app shows: an olive tree growing, on the theme's
/// own gradient.
///
/// It replaces the blank frame the startup reconciliation used to sit
/// behind. The wait is real either way — this one says what the app is
/// about while it happens, and it never *causes* the wait: the screen
/// leaves as soon as both the tree is grown and startup has finished.
class SplashScreen extends StatefulWidget {
  const SplashScreen({this.onGrown, super.key});

  /// Fired once the tree reaches fruit — the app leaves when this and
  /// startup have both landed.
  final VoidCallback? onGrown;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: splashGrowth,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onGrown?.call();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    // Reduce-motion means no growing: the tree is simply there.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      widget.onGrown?.call();
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: HarvestBrand.gradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // A square box, so the tree is as big as the narrower of
              // the two dimensions allows instead of stranded at the
              // foot of a tall one.
              Flexible(
                flex: 8,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => GrowingOliveTree(
                        progress: Curves.easeOut.transform(_controller.value),
                        wood: Colors.white,
                        foliage: Colors.white.withValues(alpha: 0.86),
                        blossom: Colors.white,
                        fruit: HarvestBrand.olive,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HarvestSpacing.lg),
              Text(
                l10n.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.loadingTagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
