# UX Clarity Audit

*Taken 2026-09-03 on the round-5 tree. Every screen read component by component with one question: does the user know what this is and what to do with it? Not a redesign — a clutter pass. Fix status lives in [[Audit-Home]].*

# Harvest UX clarity audit

Scope: `docs/00-Overview/Vision.md`, `docs/01-Specification/*.md`, and every presentation file listed in the brief, plus the non-UI code I needed to verify claims (`notification_planner.dart`, `finances_repository.dart`, `streak_service.dart`, `router.dart`).

## Cross-cutting findings (the things that generate most of the clutter)

1. **Spending is charted in three places.** `StatsScreen._SpendingBreakdown` (month by category), `StatsScreen._WeeklyReportCard` ("Top spending: X"), and `FinanceInsights._CategoryDonut` (week/month by category). Insights is the only place with a range switch and totals; it should own spending. Stats should keep only the one-line "Top spending" in the weekly report.
2. **XP is shown twice with the same number.** `_FieldHeader` shows `XpBar` ("Sprout · 1,234 XP") plus "N XP to the next rank"; `StatsScreen` shows a "Lifetime XP" `StatTile` with the identical `xpTotalProvider` value. The Field version is the motivational one; the Stats tile is redundant.
3. **Budget is on Field and Granary, worded differently.** Field: `budgetFloating` = "DA500 / DA1,200 today". Granary `_BudgetCard`: "SPENT TODAY DA500 · Daily limit · DA1,200 · DA700 left today · month bar · DA20,000 of DA60,000 this month · DA40,000 left this month". Six numbers on one card. The spec asks for a one-line pillar gauge on the Field, so keep the Field row but make it say the same thing as the card's headline ("DA700 left today").
4. **A dead setting.** `expectedDailyMinor` is written by `_BudgetSheet` ("Expected daily spend") and read by nothing (`grep expectedDaily lib` finds only the setter, the provider, and the label). Remove the field.
5. **Coins have no store and are invisible until day 7.** Coins are only granted at 7/30/100-day streak milestones (`streakMilestoneCoins = {7: 50, 30: 200, 100: 1000}`) and only spent on freezes (`freezeCost = 100`). The only place "coins" appears is `_StreakSheet`: an unlabelled `Icons.paid` + number, and a "Buy a freeze · 100 coins" button that is disabled for every new user with no explanation of how to earn coins. The expense sheet also fires `showCheckInBurst(icon: Icons.paid)` although logging an expense grants XP (`expenseLogXp = 10`), not coins, so the icon promises the wrong reward.
6. **Reminders the user cannot see or control.** `NotificationPlanner._planRituals` schedules five daily rituals: morning, evening plan, **expense check-in (20:00, key `ReminderKeys.expenseTime`)**, **prime-time nudge (learned time, "Your crops are waiting")**, and streak-risk (**fixed 23:00**). `SettingsScreen` exposes only morning, evening and the streak switch. The expense time has an unused string (`remindersExpense`) and no row; prime time is mentioned nowhere in the UI; the 23:00 time is never displayed.
7. **"Barn" is a place that doesn't exist.** `archiveConfirmBody` ("moves to the barn"), `projectDoneBody`, and the `toTheBarn` button all send seeds to a barn, but there is no archived-items view anywhere (`router.dart` has no such route). Either a dead-end concept or a missing screen; for a clutter pass, rename to "Archive".
8. **Money flows ask a question that a default could answer.** Expense → `showChoiceSheet` "Take it from the wallet?"; savings deposit → "Where does it come from?"; savings withdraw → "Where does it go?"; debt pay → "Pay from the wallet?". Four extra sheets, all answerable by a toggle inside the amount sheet. Worse: the withdraw-as-expense path hardcodes `ExpenseCategory.other` (`vault_tab.dart` `_withdraw`), and `_RepeatCard`'s "Log it" never asks the wallet question at all, so the same action behaves differently in two places. Also verified: deleting or editing an expense (`FinancesRepository.remove/updateExpense`) does not touch the wallet `TxnKind.expense` row it created, so "Yes, from the wallet" leaves a ghost withdrawal if the expense is later swiped away.
9. **Dead strings** (0 usages outside generated code): `remindersExpense`, `recentMoves`, `txnWallet`, `txnSavings`, `nothingInVault`, `savingsIn`, `savingsLabel`, `currencyLabel`, `walletEmptyTitle/Body`, `savingsEmptyTitle/Body`, `swipeToRemove`, `todoOverdue`. Leftovers from the pre-vault ledger and from the one-currency era.
10. **Accessibility baseline.** Only two `Semantics` widgets exist in the whole app (`StreakFlame`, `_BlockDots`), and the `StreakFlame` label is a hardcoded English string. No `IconButton` has a `tooltip`. `Dismissible` swipe-to-delete has no hint (its string is unused). Vault section selection (`StatTile.selected`) is distinguished by tint and border only.

## Per-screen tables

### Shell (`lib/app/shell.dart`)

| Component | Verdict | Reason |
|---|---|---|
| `NavigationBar` with Field / Granary / Stats / Settings | keep | Four destinations is right; haptic tick on switch is fine. |
| Label "Granary" with `Icons.account_balance_wallet` | rename | The icon already says "wallet/money"; the label should too. "Money" is what the user is looking for. |
| Label "Field" with `Icons.grass` | keep | It is the app's one metaphor worth teaching; onboarding explains it. |

### Field (`lib/features/field/field_screen.dart`, `crop_card.dart`, `xp_bar.dart`, `streak_flame.dart`, `deadline_countdown.dart`)

| Component | Verdict | Reason |
|---|---|---|
| AppBar title "Harvest" | keep | |
| Calendar `IconButton` (`Icons.calendar_month_outlined`) | keep, add tooltip | Icon-only, no `tooltip`. |
| `MiniTimerChip` idle state: `IconButton(Icons.timer_outlined)` opening a free session | keep, add tooltip | It is the only door to a free focus session; needs "Focus timer" tooltip. |
| `MiniTimerChip` running state: `ActionChip` "12:34" | keep | Good affordance, ticks, tap returns to timer. |
| `StreakFlame` wrapped in `InkWell` → `showStreakSheet` | keep, add affordance | Nothing says the flame is tappable, and the sheet is the only place freezes/coins live. Give it a `Tooltip`/`Semantics(button: true)` and the sheet a real reason to exist (see Streak sheet). |
| `_FieldHeader`: `XpBar` (rank label + "N XP" + gradient bar) | keep | The always-visible progress the spec calls for. |
| `_FieldHeader`: "N XP to the next rank" line | remove | The bar already encodes it; a third line of chrome above the crops. |
| `_FieldHeader`: budget row "DA500 / DA1,200 today" + `IconBadge` + chevron → `context.go(finances)` | simplify | Keep the one-line pillar gauge but word it as the Granary headline does ("DA700 left today") so it is one concept, not a fraction the user has to decode. |
| `HarvestFab` "Plant a seed" | keep | Clear primary action. |
| `CropCard` tap = check-in / undo dialog / quantity sheet | keep | Core gesture; matches spec. |
| `CropCard` long-press → `showCropOptions` | keep, add visible affordance | Edit/pause/archive/focus are only reachable by long-press. A small trailing overflow (`more_vert`) or a swipe hint would surface it; long-press can stay as the shortcut. |
| `CropCard` subtitle for habits = literally "Habit" (`l10n.typeHabit`) | remove | Tells the user nothing; the `Icons.repeat` avatar already marks the type. Show the schedule ("Mon · Wed · Fri", "3× a week · 1 done") or nothing. |
| `CropCard` subtitle for to-dos = note or "To-Do" | simplify | Same: drop the type fallback, show note or planned date. |
| Project subtitle "12 of 300 · today 0/10" | keep | Dense but exactly what a project needs. |
| `DeadlineCountdown` (hourglass, "2d 4h", ticking under 3h) | keep | Useful urgency, but see editor note on to-do deadlines. |
| Done crops: strike-through + 50% alpha + green check | keep | Not colour-only. |
| Undo dialog "Undo today's check-in?" on tapping a done crop | keep | Mis-taps happen; a dialog is the right guard. |
| Quantity sheet "Water this crop" / "How much did you get done?" / "You can log N more today" | keep, rename title | Helper text is excellent; title is jargon. |
| Project-complete dialog "Harvest complete! … moves to the barn with pride" → "To the barn" | rename | No barn exists. "Archive" / "Done". |
| `_TomorrowCard` ("Tomorrow · Thu, Sep 4", "2 habits due · 1 to-do planned", "Plan ›") | keep | The explicit door the spec wants; clear. |
| `_EmptyField` "Your field is ready / Plant your first seed…" (no button) | keep | FAB is visible right below; adding a second button would duplicate it. |

### Crop options sheet (`crop_options_sheet.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Title = commitment title | keep | |
| "Focus timer" | keep | |
| "Edit seed" | keep, rename | "Edit". |
| "Pause (vacation)" / "Resume" (habits only) | keep | Spec'd anti-burnout guardrail; label is understandable. |
| "Archive" with confirm dialog | keep, reword body | "Its history stays" is good; drop "barn". |
| No "Delete" | keep as-is | Archive is delete-with-history; one removal verb is less confusing than two. |

### Commitment editor (`commitment_editor_sheet.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Type `SegmentedButton` Habit / Project / To-Do (hidden in edit mode) | keep | |
| Title field with per-type hint | keep | |
| Habit schedule segmented: "Daily / Weekdays / Every X days / X per week" | rename one | "Weekdays" is a specific-days picker (Mon/Wed/Fri), not "Mon–Fri". Call it "Some days". |
| Weekday `FilterChip` row, interval `_Stepper`, times-per-week `_Stepper` | keep | |
| Project: "Total target (pages, minutes…)" + "Daily commitment" | keep | |
| To-do: "Planned for" Today / Tomorrow / Pick a date | keep | |
| Advanced `ExpansionTile`: Note, Remind me at, Accomplish before | simplify | For a to-do there are now two dates: "Planned for" (when it appears) and "Accomplish before" (when it turns red). Almost always the same day. Drop the deadline for to-dos, keep it for projects; mark a to-do overdue when `dueDay < today` (the unused `todoOverdue` string was meant for this). |
| Clear-X `IconButton`s on reminder/deadline | keep, add tooltip | Icon-only. |
| `_Stepper` +/- `IconButton.filledTonal` | keep, add tooltip | Icon-only. |
| `BigBouncySheetButton` "Save" | keep | |

### Streak sheet (`gamification/presentation/streak_sheet.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Title "Your streak" | keep | |
| `Icons.paid` + bare number (coin balance) | remove or label | Unlabelled number in the corner; nothing in the app says "coins". |
| Flame + "N days" + "Best: N" | keep | The one thing users open this for. |
| "Streak freezes: N of 2" + explainer | keep | Clear. |
| "Buy a freeze · 100 coins" `FilledButton` | simplify | Disabled for everyone until a 7-day streak, with no hint why. Either add "Earn 50 coins at a 7-day streak" or (my preference) drop the coin economy from the UI: grant a freeze automatically at each milestone and show "Next freeze at 7 days". |

### Planner (`planner/presentation/planner_screen.dart`)

| Component | Verdict | Reason |
|---|---|---|
| AppBar "Tomorrow's plan" | keep | |
| Quick-add `TextField` "Plant a to-do for tomorrow…" | keep | The ritual's core input; fast. |
| Empty text "Nothing planned yet. Add tomorrow's seeds tonight…" | keep | |
| To-do `Card`s with close-X `IconButton` (archives, no confirm) | keep, add tooltip | Undo-less but low stakes for a just-typed to-do; needs "Remove" tooltip. |
| "Habits due tomorrow" read-only `Card` list | simplify | Pure information; a one-line summary ("Also due: Exercise, Journal") saves half the screen. |
| Three ways to plant a to-do for tomorrow (this field, editor "Tomorrow" chip, Calendar quick-add on tomorrow) | keep, unify | They serve different entry points; make the hint text identical ("Add a to-do for …") so they read as one feature. |

### Calendar (`calendar/presentation/calendar_screen.dart`)

| Component | Verdict | Reason |
|---|---|---|
| `TableCalendar` month view with count badge | keep | Badge beats dots (as the comment says). |
| Projects listed on every day (`case CommitmentType.project: entries.add(...)`) | remove from calendar | With two projects every single day shows "2+" and the badge stops meaning anything. Projects are implicitly daily; show them once in a header or not at all. |
| Quick-add `TextField` for today/future days | keep | |
| Entry `Card`s (non-tappable) | simplify | Dead end: you can see "Exercise" on Sep 12 but cannot open, edit or check it in. Tap → `showCropOptions`/editor. |
| Deadline entries "Deadline: X" in red | keep | |
| Empty "Nothing planted for this day." | keep | |

### Pomodoro (`pomodoro_screen.dart`, `mini_timer_chip.dart`, `pomodoro_controller.dart`)

| Component | Verdict | Reason |
|---|---|---|
| AppBar "Focus", commitment title / "Free focus" | keep | |
| Ring + "mm:ss" + phase label; `_BlockDots` with `Semantics` | keep | |
| Start focus / Pause / Resume / Finish session / Abandon / "The field will wait." | keep, fix label | When paused mid-block after ≥1 block, the label logic `blocksDone > 0 && !isRunning ? startFocus : resume` shows "Start focus" instead of "Resume". |
| Finish on a project → `SnackBar("Nice work! Log your progress on the field.")` then pop | simplify | Dead end that contradicts `Pomodoro.md` ("opens the quantity sheet pre-focused"). Open the quantity sheet directly. |
| Ongoing notification title | fix | `_showOngoing` uses `phaseShortBreak` for long breaks too. |
| Settings: 4 stepper rows | keep | Spec'd, understandable. |

### Granary — Today tab (`granary_screen.dart`, `expense_sheet.dart`, `choice_sheet.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Tabs Today / Vault / Insights | keep, rename Vault | "Vault" is jargon for "Balances". |
| FAB "Log an expense" (Today only) | keep | |
| No-budget `EmptyState` + "Set a monthly budget" | keep | Clear first-run. |
| `_BudgetCard`: `GaugeRing` + "SPENT TODAY" + big amount | keep | |
| `_BudgetCard`: "Daily limit · DA1,200" line | remove | The ring and "DA700 left today" already say it; explain the floating limit once in the budget sheet instead. |
| `_BudgetCard`: "DA700 left today" | keep | The actionable number. |
| `_BudgetCard`: month bar + "DA20,000 of DA60,000 this month" + "DA40,000 left this month" | merge | One line: "DA20,000 of DA60,000 · DA40,000 left". |
| `_BudgetCard` whole-card `onTap` → budget sheet, with decorative `Icons.tune` | keep, make icon the button | The card tap is hidden; the tune icon looks like a button but isn't one. Give it a `tooltip: "Edit budget"` and make it the tap target. |
| `_RepeatCard` "DA300 · Food / Same as the last 3 days? / Log it" | keep, align | Good. But it skips the wallet question the FAB flow asks — same default should apply. |
| `SectionHeader` "Today · 3 expenses · DA1,150" | keep | |
| Empty card "Nothing logged today. What did you spend?" + body reused from `notifExpenseBody` | keep, reword | "keep the granary honest" is jargon in a UI string. |
| `_ExpenseRow` tap → edit | keep | |
| `_ExpenseRow` `Dismissible` swipe-to-delete, snackbar "Removed", no undo | simplify | No hint (`swipeToRemove` unused), no undo, and it orphans the wallet withdrawal. Either add an Undo action to the snackbar that also reverses the vault move, or move delete into the edit sheet. |
| Expense sheet: amount + currency `SegmentedButton` (DA/$/€ always) | keep | Small; multi-currency is real for this owner. |
| Expense sheet: category `ChoiceChip`s + "New category" `ActionChip` | keep | |
| `showCategoryCreator` dialog: name + 20 icon cells (34px) | keep, enlarge targets | Icon cells are ~34px; below 48px. |
| After "Log": `showChoiceSheet` "Take it from the wallet?" | merge into sheet | A `SwitchListTile` "From the wallet (DA5,000)" inside the expense sheet, default on when the wallet holds ≥ amount in that currency, off otherwise. Removes a whole sheet from the sub-5-second log. |
| `showCheckInBurst(icon: Icons.paid)` | change icon | XP is granted, not coins; use the leaf/XP icon so the reward is truthful. |

### Granary — Vault tab (`vault_tab.dart`, `money_sheet.dart`, `debt_sheet.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Three `StatTile` selectors "Wallet / Savings / Owed" | keep, rename "Owed" → "Debts" | Tile says "Owed", hero eyebrow says "OWED", empty state says "No debts", button says "Log a debt". One word. |
| Selected-tile state (tint + border only) | add non-colour cue | Colour-only selection; a check icon or bolder label helps. |
| Wallet `HeroCard`: balances + "Add" / "Take" | keep | Simple and clear. |
| Savings `HeroCard`: balances + "Save" / "Withdraw" + low-savings warning | keep | |
| Savings deposit → "Where does it come from?" (From the wallet / New money) | merge | Toggle inside `showMoneySheet`: "From the wallet (DA5,000 available)". |
| Savings withdraw → "Where does it go?" (To the wallet / Log as expense) | remove the second option | "Log as expense" writes an "Other" expense with no category choice. Withdraw always to the wallet; log the expense from the wallet as usual. One fewer sheet, no mis-categorised entries. |
| Debts `HeroCard`: "OWED" + "3 open debts" + totals + "Log a debt" | keep | |
| `_DebtCard`: person, "Pay off by … · note", remaining, progress, "X of Y paid", "Payments · N" toggle, "Pay" | keep | Dense but every item is used. |
| Debt pay → amount sheet (prefilled remaining) → "Pay from the wallet?" | merge | Same toggle. |
| `_DebtSheet`: person, amount, currency, pay-off-by, remind-at, note | keep | "Remind me at" defaults to 19:00 daily nagging even when unset (`row.remindAt ?? '19:00'`); tell the user that in the row's subtitle ("Daily at 7:00 PM until paid"). |
| Settled debts `LedgerRow` list | keep | |
| "Moves" ledger with kind titles ("Added", "Taken out", "From savings", "Expense · Food", "Paid Sami") | keep | The ledger explains itself, as the spec intended. |
| Conversion captions "≈DA1,080" | keep | |

### Granary — Insights tab (`finance_charts.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Week / Month `SegmentedButton` | keep | |
| "Total" tile | keep | |
| Average tile with label `l10n.avgPerDay('')` → " / day" | fix label | Renders with a leading space and no noun; add a "Per day" string. |
| Daily `BarChart` (touch disabled) | keep | |
| Category donut + legend with % | keep | This is the single owner of spending breakdown. |
| Empty "No spending in this range yet." | keep | |

### Budget sheet (`granary_screen.dart` `_BudgetSheet`)

| Component | Verdict | Reason |
|---|---|---|
| "Budget for the month" amount | keep | Add one helper line: "Your daily limit is what's left ÷ days left." |
| "Default currency" `SegmentedButton` | move | Belongs with exchange rates under Settings › Money; a budget sheet should only be a budget. |
| "Expected daily spend" | remove | Stored, never read. |
| `_ManageCategories` chips with delete | move | Managing categories inside the budget dialog is unfindable. Put a "Categories" row under Settings › Money. |
| Save | keep | |

### Stats (`stats/stats_screen.dart`)

| Component | Verdict | Reason |
|---|---|---|
| "Lifetime XP" tile | remove | Same value as the Field header. |
| "Best streak" tile | keep | Only place the best is shown outside the sheet. |
| "Check-ins" tile | keep | |
| "This week" card: XP, "Best: Monday", "Quietest: Sunday", "Top spending: Food" | keep | Compact; spec'd weekly report. |
| Activity `_HeatMap` (10 weeks, reversed scroll, no month labels, no semantics) | keep, add legend/labels | Unreadable without a scale; at minimum month labels and a `Semantics` summary. |
| "Projects" progress cards (subtitle built via `projectSubtitle(...).split('·').first`) | keep, add a proper string | The split hack will break if the Arabic string uses a different separator. |
| "Spending by category" `_SpendingBreakdown` | remove | Duplicate of Insights' donut. |
| "Habit streaks" list "N now · best N" | keep | |
| Empty state hides everything when `checkIns == 0` | keep | |

### Settings (`settings_screen.dart`, `rates_card.dart`)

| Component | Verdict | Reason |
|---|---|---|
| Section order: Harvest, Exchange rates, Focus timer, Reminders, Appearance | reorder | Rates as the second thing on the page is odd: Goal → Reminders → Focus timer → Money → Appearance. |
| "Daily Harvest Goal" stepper + body text | keep, add tooltips | Clear explanation; +/- are icon-only. |
| `RatesCard`: "DZD per 1 USD", "DZD per 1 EUR" fields (saved on tap-outside, no feedback), "EUR → USD (fetched)" + Fetch | simplify | Nothing tells the user what rates are for. Group as "Money": Default currency, Categories, then rates with a subtitle "Used to show $ and € amounts in DA". Confirm saves with a snackbar. |
| Reminders: "Allow reminders" master | keep | |
| "Morning review" / "Evening plan ritual" time rows | keep, rename | Match the notification copy (see rename list). |
| "Streak-risk nudge" switch | keep, add time | Show "11:00 PM" as subtitle; the time is hardcoded and invisible. |
| Expense check-in (20:00) — no row | add | Planner schedules it; the string `remindersExpense` exists; the user cannot move or disable it. |
| Prime-time nudge — no row, no mention | remove | A learned-time notification the user cannot see, explain or switch off individually. Morning → evening → 23:00 already covers the escalation. |
| Theme segmented, 5 `_PresetSwatch`es, Language segmented | keep | |

### Onboarding (`onboarding_screen.dart`)

| Component | Verdict | Reason |
|---|---|---|
| "Skip" `TextButton` → `_finish()` which still plants the preselected `read` + `fit` seeds | fix | Skipping should not silently create two commitments. Skip with an empty pick set, or don't preselect. |
| Welcome page | keep | |
| Templates `FilterChip`s (5) | keep | |
| Goal page titled "Your daily commitment" | rename | Collides with the project field "Daily commitment" (units per day). Use the same words as Settings: "Daily Harvest Goal". |
| Reminders page with "Allow reminders" switch | keep | |
| Page dots + Next / "Start growing" | keep | |
| Missing first-check-in demo (spec step 6) | skip for now | Not clutter; the FAB and preselected crops make the first tap obvious enough. |

### Shared widgets (`lib/core/ui/widgets/*.dart`)

| Component | Verdict | Reason |
|---|---|---|
| `BigBouncyButton`, `HarvestFab`, `HeroCard`, `Eyebrow`, `IconBadge`, `SectionHeader`, `EmptyState`, `GaugeRing`, `LedgerRow`, `groupByDay` | keep | Consistent, reused, not user-facing clutter. |
| `StreakFlame` `Semantics(label: 'Streak: $days days')` | fix | Hardcoded English; use an l10n string. |
| `StatTile` as a selector | add cue | See Vault. |
| `LedgerRow` deposits: "+" sign plus green | keep | Sign carries the meaning, colour is secondary. |

## Top 15 changes

| ID | Change | Files |
|---|---|---|
| U-01 | Collapse the wallet question into the amount sheets: add a "From the wallet (balance)" `SwitchListTile` to `_ExpenseSheet` and `showMoneySheet` (deposit/pay), defaulting on when the wallet holds ≥ amount; delete the four `showChoiceSheet` calls. Apply the same default to `_RepeatCard`. | `finances/presentation/expense_sheet.dart`, `money_sheet.dart`, `vault_tab.dart`, `granary_screen.dart`; `choice_sheet.dart` becomes unused |
| U-02 | Remove the "Log as expense" withdraw destination; withdrawals always go to the wallet. | `vault_tab.dart` (`_withdraw`), `app_en.arb`/`app_ar.arb` (`withdrawDestination`, `asExpense`, `toWallet`) |
| U-03 | Remove "Expected daily spend" and its setting. | `granary_screen.dart` (`_BudgetSheet`), `finance_providers.dart` (`FinanceKeys.expectedDaily`, `setExpectedDaily`), arb (`expectedDailyLabel`) |
| U-04 | Move Default currency, Exchange rates and Custom categories into a "Money" section in Settings; budget sheet keeps only the amount plus one helper line about the floating limit. | `settings_screen.dart`, `rates_card.dart`, `granary_screen.dart` (`_BudgetSheet`, `_ManageCategories`) |
| U-05 | Delete `_SpendingBreakdown` and the "Lifetime XP" tile from Stats; Insights owns spending, Field owns XP. | `stats/stats_screen.dart` |
| U-06 | Simplify `_BudgetCard`: drop "Daily limit · X", merge the two month lines, make `Icons.tune` the tappable "Edit budget" control with a tooltip. Word the Field row as "DA700 left today". | `granary_screen.dart`, `field/field_screen.dart` (`_FieldHeader`), arb |
| U-07 | Reminders settings: add the expense check-in time row (string `remindersExpense` exists, key `ReminderKeys.expenseTime`), show "11:00 PM" on the streak row, remove the prime-time nudge from the planner. | `settings_screen.dart`, `settings_controllers.dart` (`ReminderSettings`), `planner/domain/notification_planner.dart` (`_primeTime`, `ReminderIds.primeTime`), arb (`notifPrime*`) |
| U-08 | Streak sheet: label or drop the coin number; replace the disabled "Buy a freeze · 100 coins" with either an earn hint or automatic freeze grants at milestones. Change the expense burst icon from `Icons.paid` to the XP/leaf icon. | `gamification/presentation/streak_sheet.dart`, `gamification/domain/streak_service.dart` (if auto-grant), `expense_sheet.dart` |
| U-09 | Give hidden gestures a visible affordance: overflow icon on `CropCard` (long-press remains), tooltip + `Semantics(button)` on the streak flame, tooltips on every icon-only `IconButton` (calendar, timer, planner X, editor clear X, all +/- steppers). | `core/ui/widgets/crop_card.dart`, `field_screen.dart`, `mini_timer_chip.dart`, `planner_screen.dart`, `commitment_editor_sheet.dart`, `settings_screen.dart`, `onboarding_screen.dart` |
| U-10 | Drop the "Accomplish before" deadline for to-dos (keep for projects); mark a to-do overdue when `dueDay < today` using the existing `todoOverdue` string; replace the "Habit"/"To-Do" type-name subtitles on `CropCard` with the schedule or nothing. | `commitment_editor_sheet.dart` (`_advancedSection`), `field_screen.dart` (`_CropTile._subtitle`, `_overdue`) |
| U-11 | Expense delete: add Undo to the snackbar and reverse the linked wallet `TxnKind.expense` move (or move delete into the edit sheet). | `granary_screen.dart` (`_ExpenseRow`), `finances/data/finances_repository.dart`, `vault_repository.dart` |
| U-12 | Pomodoro: finishing on a project opens the quantity sheet instead of a snackbar; fix the "Start focus"/"Resume" label; fix the long-break notification title. | `pomodoro_screen.dart` (`_finish`, `_buttons`), `pomodoro_controller.dart` (`_showOngoing`), `field_screen.dart` (extract `_showQuantitySheet` so both can call it) |
| U-13 | Calendar: stop listing projects on every day; make entry rows tappable (options sheet / editor). | `calendar/presentation/calendar_screen.dart` |
| U-14 | Onboarding: Skip must not plant the preselected seeds; retitle the goal page to match Settings. | `onboarding_screen.dart` (`_finish`, `_GoalPage`), arb (`obGoalTitle`) |
| U-15 | Delete the dead strings and localise the `StreakFlame` semantics label; fix the " / day" tile label; unify "Owed"/"Debts". | `app_en.arb`, `app_ar.arb`, `streak_flame.dart`, `finance_charts.dart`, `vault_tab.dart` |

## Strings and labels to rename

| Key (current text) | Proposed | Why |
|---|---|---|
| `navGranary` / `granaryTitle` ("Granary") | "Money" | Icon is a wallet; "granary" needs the glossary. |
| `vaultTab` ("Vault") | "Balances" | Plain word for wallet + savings + debts. |
| `vaultOwed` ("Owed") | "Debts" | Match `debtsTitle`, `addDebt`, `debtsEmptyTitle`. |
| `scheduleWeekly` ("Weekdays") | "Some days" | It picks specific days, not Mon–Fri. |
| `logProgressTitle` ("Water this crop") | "Log progress" | Helper text already carries the metaphor. |
| `toTheBarn` ("To the barn"), `archiveConfirmBody` ("moves to the barn…"), `projectDoneBody` ("…moves to the barn with pride") | "Archive" / "…is archived. Its history stays." | No barn screen exists. |
| `editSeed` ("Edit seed") | "Edit" | Inside a sheet already titled with the crop's name. |
| `obGoalTitle` ("Your daily commitment") | "Daily Harvest Goal" | Collides with `dailyCommitmentLabel` (project units/day). |
| `remindersMorning` ("Morning review") | "Morning: today's plan" | Matches `notifMorningBody`. |
| `remindersEvening` ("Evening plan ritual") | "Evening: plan tomorrow" | Matches `notifEveningBody` and `plannerTitle`. |
| `remindersStreak` ("Streak-risk nudge") | "Late streak warning (11 PM)" | Says what and when. |
| `remindersExpense` ("Expense check-in") | keep text, wire it up | Currently unused. |
| `budgetFloating` ("{spent} / {limit} today") | reuse `budgetLeftToday` ("{amount} left today") | One wording on Field and Granary. |
| `budgetSpentOf` + `budgetLeftMonth` | "{spent} of {budget} · {left} left" | One line instead of two. |
| `avgPerDay` ("{amount} / day") used as a tile label with `''` | new key "Per day" | Renders as " / day". |
| `notifExpenseBody` reused as the empty-state body ("…keep the granary honest") | separate empty-state string: "Tap Log an expense to add one." | Notification voice inside a screen, plus jargon. |
| `plannerAddHint` / `calAddForDay` ("Plant a to-do for tomorrow…" / "…for this day…") | "Add a to-do for tomorrow…" / "Add a to-do for {date}…" | Same feature, same verb. |
| `debtRemindAt` ("Remind me at") | "Daily reminder at" | It nags daily until paid; default 7:00 PM even when unset. |
| `coinBalance` ("{count}") | "{count} coins" (if coins stay) | A bare number next to an icon is not a label. |
| `StreakFlame` Semantics `'Streak: $days days'` | l10n key | Hardcoded English in an EN/AR app. |
| Dead keys to delete | `recentMoves`, `txnWallet`, `txnSavings`, `nothingInVault`, `savingsIn`, `savingsLabel`, `currencyLabel`, `walletEmptyTitle/Body`, `savingsEmptyTitle/Body`, `swipeToRemove` (unless U-11 uses it), `expectedDailyLabel`, `withdrawDestination`/`asExpense`/`toWallet` (after U-02), `notifPrimeTitle/Body` (after U-07) | Zero usages outside generated code. |
