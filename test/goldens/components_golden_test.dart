import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/core/ui/widgets/hero_card.dart';
import 'package:harvest/core/ui/widgets/ledger_row.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/core/ui/widgets/streak_flame.dart';
import 'package:harvest/core/ui/widgets/xp_bar.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Golden coverage for the signature components across theme x direction.
/// Regenerate with: flutter test --update-goldens test/goldens
void main() {
  Widget gallery(ThemeData theme, TextDirection direction) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    // The signature widgets speak: they need the app's strings.
    locale: direction == TextDirection.rtl
        ? const Locale('ar')
        : const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  StreakFlame(days: 12),
                  SizedBox(width: HarvestSpacing.lg),
                  StreakFlame(days: 0),
                ],
              ),
              const SizedBox(height: HarvestSpacing.md),
              const XpBar(
                xp: 1450,
                rankLabel: 'Seedling',
                xpPerRank: 1000,
              ),
              const SizedBox(height: HarvestSpacing.md),
              CropCard(
                title: 'Exercise',
                subtitle: 'Habit',
                icon: Icons.repeat,
                done: false,
                onTap: () {},
              ),
              CropCard(
                title: 'Read Atomic Habits',
                subtitle: '40 of 300 · today 10/10',
                icon: Icons.flag,
                done: true,
                progress: 0.4,
                onTap: () {},
              ),
              BigBouncyButton(
                onPressed: () {},
                icon: Icons.add,
                child: const Text('Plant a seed'),
              ),
              const SizedBox(height: HarvestSpacing.md),
              const HeroCard(
                padding: EdgeInsets.all(HarvestSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Wallet'),
                    Text(
                      'DA12,500',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Moves', subtitle: 'Every movement'),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.account_balance_wallet,
                        label: 'Wallet',
                        value: 'DA12,500',
                        selected: true,
                      ),
                    ),
                    SizedBox(width: HarvestSpacing.sm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.savings,
                        label: 'Savings',
                        value: 'DA3,000',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HarvestSpacing.sm),
              Card(
                child: Column(
                  children: [
                    LedgerRow(
                      icon: Icons.add_circle,
                      color: theme.colorScheme.secondary,
                      title: 'Added',
                      subtitle: 'Salary',
                      amount: '+DA12,500',
                      amountColor: theme.colorScheme.secondary,
                    ),
                    LedgerRow(
                      icon: Icons.restaurant,
                      color: theme.colorScheme.error,
                      title: 'Expense · Food',
                      amount: r'−$8',
                      caption: '≈DA1,080',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final variants = {
    'light_ltr': (HarvestTheme.light(ThemePreset.harvest), TextDirection.ltr),
    'light_rtl': (HarvestTheme.light(ThemePreset.harvest), TextDirection.rtl),
    'dark_ltr': (HarvestTheme.dark(ThemePreset.harvest), TextDirection.ltr),
    'dark_rtl': (HarvestTheme.dark(ThemePreset.harvest), TextDirection.rtl),
  };

  for (final entry in variants.entries) {
    testWidgets('components ${entry.key}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      await tester.pumpWidget(gallery(entry.value.$1, entry.value.$2));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/components_${entry.key}.png'),
      );
    });
  }
}
