// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'حصاد';

  @override
  String get navField => 'الحقل';

  @override
  String get navStats => 'الإحصائيات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get fieldEmptyTitle => 'حقلك جاهز';

  @override
  String get fieldEmptyBody =>
      'ازرع بذرتك الأولى — عادة، مشروعًا، أو مهمة بسيطة.';

  @override
  String get statsEmptyTitle => 'لا شيء لنحصيه بعد';

  @override
  String get statsEmptyBody => 'ستنمو أرقام حصادك هنا كلما سجّلت أيامك.';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get langSystem => 'النظام';

  @override
  String get langEnglish => 'English';

  @override
  String get langArabic => 'العربية';

  @override
  String get addCommitment => 'ازرع بذرة';

  @override
  String get typeHabit => 'عادة';

  @override
  String get typeProject => 'مشروع';

  @override
  String get typeTodo => 'مهمة';

  @override
  String get titleLabel => 'العنوان';

  @override
  String get titleHintHabit => 'مثل: تمرين، ممارسة الإسبانية';

  @override
  String get titleHintProject => 'مثل: قراءة كتاب العادات الذرية';

  @override
  String get titleHintTodo => 'مثل: الاتصال بطبيب الأسنان';

  @override
  String get scheduleLabel => 'الجدول';

  @override
  String get scheduleDaily => 'يوميًا';

  @override
  String get scheduleWeekly => 'أيام محددة';

  @override
  String get scheduleInterval => 'كل عدة أيام';

  @override
  String get scheduleTimesPerWeek => 'مرات في الأسبوع';

  @override
  String everyDaysLabel(int count) {
    return 'كل $count أيام';
  }

  @override
  String timesPerWeekLabel(int count) {
    return '$count مرات في الأسبوع';
  }

  @override
  String get totalTargetLabel => 'الهدف الكلي (صفحات، دقائق…)';

  @override
  String get dailyCommitmentLabel => 'الالتزام اليومي';

  @override
  String get dueLabel => 'مخطط ليوم';

  @override
  String get dueToday => 'اليوم';

  @override
  String get dueTomorrow => 'غدًا';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get undoCheckInTitle => 'التراجع عن إنجاز اليوم؟';

  @override
  String undoCheckInBody(String title) {
    return 'سيؤدي هذا إلى حذف ما سجلته لـ «$title» اليوم.';
  }

  @override
  String get undo => 'تراجع';

  @override
  String get logProgressTitle => 'تسجيل التقدم';

  @override
  String get logQuantityLabel => 'كم أنجزت؟';

  @override
  String logRemainingToday(int count) {
    return 'يمكنك تسجيل $count إضافية اليوم';
  }

  @override
  String get log => 'سجّل';

  @override
  String get cappedMessage => 'بلغت الحد اليومي — الحقل يستريح أيضًا.';

  @override
  String xpEarned(int count) {
    return '+$count نقطة خبرة';
  }

  @override
  String projectSubtitle(int done, int total, int today, int daily) {
    return '$done من $total · اليوم $today/$daily';
  }

  @override
  String get todoOverdue => 'متأخرة';

  @override
  String get rankSprout => 'برعم';

  @override
  String get rankSeedling => 'شتلة';

  @override
  String get rankGardener => 'بستاني';

  @override
  String get rankHarvester => 'حصّاد';

  @override
  String get rankMasterFarmer => 'مزارع خبير';

  @override
  String get settingsHarvest => 'الحصاد';

  @override
  String get settingsGoalTitle => 'هدف الحصاد اليومي';

  @override
  String get settingsGoalBody =>
      'عدد الإنجازات المطلوبة كل يوم للحفاظ على سلسلتك.';

  @override
  String goalActions(int count) {
    return '$count إنجازات في اليوم';
  }

  @override
  String get streakSheetTitle => 'سلسلتك';

  @override
  String streakCurrent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return '$_temp0';
  }

  @override
  String streakBest(int count) {
    return 'الأفضل: $count';
  }

  @override
  String freezesStored(int count, int max) {
    return 'تجميدات السلسلة: $count من $max';
  }

  @override
  String get freezeExplainer =>
      'التجميد يحمي سلسلتك ليوم واحد فائت، ويُستخدم تلقائيًا.';

  @override
  String buyFreeze(int cost) {
    return 'اشترِ تجميدًا · $cost عملة';
  }

  @override
  String get freezeBought => 'تم تخزين التجميد. نم مرتاحًا. ❄️';

  @override
  String get freezeUnavailable => 'لا تكفي العملات، أو المخزن ممتلئ.';

  @override
  String coinBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملات',
      two: 'عملتان',
      one: 'عملة واحدة',
      zero: 'لا عملات',
    );
    return '$_temp0';
  }

  @override
  String get pomodoroTitle => 'تركيز';

  @override
  String get phaseFocus => 'تركيز';

  @override
  String get phaseShortBreak => 'استراحة قصيرة';

  @override
  String get phaseLongBreak => 'استراحة طويلة';

  @override
  String get startFocus => 'ابدأ التركيز';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف';

  @override
  String get finishSession => 'إنهاء الجلسة';

  @override
  String get abandonSession => 'مغادرة';

  @override
  String get abandonBody => 'الحقل سينتظرك.';

  @override
  String get freeSession => 'تركيز حر';

  @override
  String blocksDone(int count) {
    return 'أُنجزت $count فترات';
  }

  @override
  String get breakOverReady => 'انتهت الاستراحة — جاهز للفترة التالية';

  @override
  String get plannerTitle => 'خطة الغد';

  @override
  String get plannerHabitsDue => 'عادات الغد';

  @override
  String get plannerTodos => 'مهام الغد';

  @override
  String get plannerAddHint => 'ازرع مهمة للغد…';

  @override
  String get plannerEmpty =>
      'لا شيء مخطط بعد. ازرع بذور الغد الليلة واستيقظ جاهزًا.';

  @override
  String get notifMorningTitle => 'صباح الخير! ☀️';

  @override
  String get notifMorningBody => 'راجع خطة حصاد اليوم وسجّل بذرتك الأولى.';

  @override
  String get notifEveningTitle => 'الشمس تغرب 🌙';

  @override
  String get notifEveningBody => 'اهدأ وازرع خطة الغد.';

  @override
  String get notifStreakTitle => 'محاصيلك عطشى! 🔥';

  @override
  String get notifStreakBody =>
      'سجّل مهامك المتبقية قبل 3 صباحًا لإنقاذ سلسلتك.';

  @override
  String get settingsReminders => 'التذكيرات';

  @override
  String get remindersMaster => 'السماح بالتذكيرات';

  @override
  String get remindersMorning => 'الصباح: خطة اليوم';

  @override
  String get remindersEvening => 'المساء: خطّط للغد';

  @override
  String get remindersStreak => 'تنبيه متأخر لخطر السلسلة';

  @override
  String get obWelcomeTitle => 'مرحبًا بك في حصاد';

  @override
  String get obWelcomeBody =>
      'أهدافك بذور، وجهدك ماء، والمشتتات أعشاب ضارة.\n\nاحضر قليلًا كل يوم، وحافظ على سلسلتك، واحصد الحياة التي تزرعها.';

  @override
  String get obTemplatesTitle => 'ازرع بذورك الأولى';

  @override
  String get obTemplatesBody =>
      'اختر بعضها للبداية — يمكنك دائمًا زراعة المزيد.';

  @override
  String get tmplRead => 'قراءة كتاب (300 صفحة)';

  @override
  String get tmplFit => 'تمرين';

  @override
  String get tmplLanguage => 'ممارسة لغة';

  @override
  String get tmplMeditate => 'تأمل (3 مرات أسبوعيًا)';

  @override
  String get tmplJournal => 'كتابة اليوميات قبل النوم';

  @override
  String get obGoalTitle => 'هدف الحصاد اليومي';

  @override
  String get obRemindersTitle => 'تذكيرات لطيفة';

  @override
  String get obRemindersBody =>
      'حصاد يذكّر ولا يزعج: مراجعة صباحية، وطقس تخطيط مسائي، وتنبيه عندما تكون سلسلتك في خطر.';

  @override
  String get next => 'التالي';

  @override
  String get skip => 'تخطي';

  @override
  String get startGrowing => 'ابدأ الزراعة 🌱';

  @override
  String get statsBestStreak => 'أفضل سلسلة';

  @override
  String get statsCheckIns => 'الإنجازات';

  @override
  String get statsActivity => 'النشاط';

  @override
  String get statsProjects => 'المشاريع';

  @override
  String get statsHabitStreaks => 'سلاسل العادات';

  @override
  String statsStreakOf(int current, int best) {
    return '$current الآن · الأفضل $best';
  }

  @override
  String get navGranary => 'المخزن';

  @override
  String get granaryTitle => 'المخزن';

  @override
  String get logExpense => 'سجّل مصروفًا';

  @override
  String get amountLabel => 'المبلغ';

  @override
  String get noteLabel => 'ملاحظة (اختياري)';

  @override
  String get catFood => 'طعام';

  @override
  String get catTransport => 'مواصلات';

  @override
  String get catBills => 'فواتير';

  @override
  String get catShopping => 'تسوق';

  @override
  String get catHealth => 'صحة';

  @override
  String get catEntertainment => 'ترفيه';

  @override
  String get catOther => 'أخرى';

  @override
  String get todaySpending => 'اليوم';

  @override
  String get budgetTitle => 'الميزانية الشهرية';

  @override
  String budgetSpentOf(String spent, String budget) {
    return '$spent من $budget هذا الشهر';
  }

  @override
  String budgetFloating(String spent, String limit) {
    return '$spent / $limit اليوم';
  }

  @override
  String get budgetSet => 'حدد ميزانية شهرية';

  @override
  String get budgetAmountLabel => 'ميزانية الشهر';

  @override
  String get granaryEmpty => 'لا شيء مسجل اليوم. ماذا أنفقت؟';

  @override
  String get repeatSuggestionTitle => 'نفس الأيام الثلاثة الماضية؟';

  @override
  String get logIt => 'سجّله';

  @override
  String get notifExpenseTitle => 'ماذا أنفقت اليوم؟ 💰';

  @override
  String get notifExpenseBody => 'سجّله بلمستين وأبقِ المخزن صادقًا.';

  @override
  String get remindersExpense => 'تذكير المصاريف';

  @override
  String get statsSpending => 'الإنفاق حسب الفئة';

  @override
  String get deleted => 'حُذف';

  @override
  String get editSeed => 'تعديل';

  @override
  String get focusTimer => 'مؤقت التركيز';

  @override
  String get pauseHabit => 'إيقاف مؤقت (إجازة)';

  @override
  String get resumeHabit => 'استئناف';

  @override
  String get pausedLabel => 'متوقفة — تستريح';

  @override
  String get archiveAction => 'أرشفة';

  @override
  String get archiveConfirmTitle => 'أرشفة هذه البذرة؟';

  @override
  String archiveConfirmBody(String title) {
    return 'ستُؤرشف \"$title\". يبقى سجلها محفوظًا.';
  }

  @override
  String get projectDoneTitle => 'اكتمل الحصاد! 🎉';

  @override
  String projectDoneBody(String title, int total) {
    return '\"$title\" اكتمل — سُجّل $total. يُؤرشف بفخر.';
  }

  @override
  String get toTheBarn => 'أرشفة';

  @override
  String get weeklyReport => 'هذا الأسبوع';

  @override
  String weeklyXp(int count) {
    return '$count نقطة خبرة';
  }

  @override
  String weeklyBestDay(String day) {
    return 'الأفضل: $day';
  }

  @override
  String weeklyWorstDay(String day) {
    return 'الأهدأ: $day';
  }

  @override
  String weeklyTopSpending(String category) {
    return 'أكثر إنفاق: $category';
  }

  @override
  String get settingsPomodoro => 'مؤقت التركيز';

  @override
  String get pomodoroFocusLen => 'مدة التركيز';

  @override
  String get pomodoroShortLen => 'الاستراحة القصيرة';

  @override
  String get pomodoroLongLen => 'الاستراحة الطويلة';

  @override
  String get pomodoroBlocks => 'الفترات قبل الاستراحة الطويلة';

  @override
  String minutesValue(int count) {
    return '$count دقيقة';
  }

  @override
  String get settingsStyle => 'الطابع';

  @override
  String get presetHarvest => 'حصاد';

  @override
  String get presetSunrise => 'شروق';

  @override
  String get presetOcean => 'محيط';

  @override
  String get presetOrchard => 'بستان';

  @override
  String get presetDusk => 'غسق';

  @override
  String get advancedOptions => 'خيارات متقدمة';

  @override
  String get seedNoteLabel => 'ملاحظة';

  @override
  String get remindMeAt => 'ذكّرني في';

  @override
  String get deadlineLabel => 'أنجز قبل';

  @override
  String get notSet => 'غير محدد';

  @override
  String get clear => 'مسح';

  @override
  String get pickDate => 'اختر تاريخًا';

  @override
  String dueOn(String date) {
    return 'الموعد $date';
  }

  @override
  String overdueBy(String date) {
    return 'متأخر — كان الموعد $date';
  }

  @override
  String get taskReminderBody => 'هناك بذرة تنتظر السقاية.';

  @override
  String get newCategory => 'فئة جديدة';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get manageCategories => 'الفئات المخصصة';

  @override
  String get todayTab => 'اليوم';

  @override
  String get insightsTab => 'تحليلات';

  @override
  String get savingsLow => 'المدخرات تنخفض';

  @override
  String get rangeWeek => 'أسبوع';

  @override
  String get rangeMonth => 'شهر';

  @override
  String get totalSpent => 'الإجمالي';

  @override
  String avgPerDay(String amount) {
    return '$amount / يوم';
  }

  @override
  String get noSpendingYet => 'لا إنفاق في هذه الفترة بعد.';

  @override
  String get calendarTitle => 'التقويم';

  @override
  String get calNothingDue => 'لا شيء مزروع لهذا اليوم.';

  @override
  String calDeadline(String title) {
    return 'موعد نهائي: $title';
  }

  @override
  String get calAddForDay => 'ازرع مهمة لهذا اليوم…';

  @override
  String get defaultCurrencyLabel => 'العملة الافتراضية';

  @override
  String get exchangeRates => 'أسعار الصرف';

  @override
  String get ratesDzdUsd => 'دينار لكل 1 دولار';

  @override
  String get ratesDzdEur => 'دينار لكل 1 يورو';

  @override
  String get ratesEurUsd => 'يورو ← دولار (يُجلب)';

  @override
  String get fetchNow => 'جلب';

  @override
  String ratesUpdated(String when) {
    return 'حُدّث $when';
  }

  @override
  String get ratesFetchFailed => 'تعذر الجلب — تحقق من الاتصال.';

  @override
  String get vaultTab => 'الأرصدة';

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get walletAdd => 'إضافة';

  @override
  String get walletTake => 'سحب';

  @override
  String get savingsSectionTitle => 'المدخرات';

  @override
  String get savingsDeposit => 'ادخر';

  @override
  String get savingsWithdraw => 'اسحب';

  @override
  String get debtsTitle => 'الديون';

  @override
  String get addDebt => 'سجّل دينًا';

  @override
  String get debtPerson => 'مستحق لـ';

  @override
  String get debtPayOffBy => 'سدّد قبل';

  @override
  String get debtRemindAt => 'تذكير يومي عند';

  @override
  String get debtPay => 'سدّد';

  @override
  String get debtSettled => 'سُدّد 🎉';

  @override
  String notifDebtTitle(String person) {
    return 'دين لـ $person';
  }

  @override
  String notifDebtBody(String amount) {
    return 'لا يزال $amount مستحقًا. الدين المسدد ينام أهنأ.';
  }

  @override
  String get dayToday => 'اليوم';

  @override
  String get dayYesterday => 'أمس';

  @override
  String get vaultOwed => 'الديون';

  @override
  String vaultOpenDebts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ديون مفتوحة',
      two: 'دينان مفتوحان',
      one: 'دين واحد مفتوح',
      zero: 'لا ديون مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get debtsEmptyTitle => 'لا ديون';

  @override
  String get debtsEmptyBody => 'لا شيء مستحق لأحد. نم هانئًا.';

  @override
  String get movesTitle => 'الحركات';

  @override
  String get noMovesYet => 'لا حركات بعد';

  @override
  String get txnAdded => 'إضافة';

  @override
  String get txnTaken => 'سحب';

  @override
  String get txnSaved => 'ادخار';

  @override
  String get txnWithdrawn => 'سحب من المدخرات';

  @override
  String get txnFromSavings => 'من المدخرات';

  @override
  String get txnToSavings => 'إلى المدخرات';

  @override
  String get txnFromWallet => 'من المحفظة';

  @override
  String get txnToWallet => 'إلى المحفظة';

  @override
  String get txnExpense => 'مصروف';

  @override
  String txnDebtPayment(String person) {
    return 'دفعة لـ $person';
  }

  @override
  String debtPaidOf(String paid, String total) {
    return 'دُفع $paid من $total';
  }

  @override
  String get debtPayments => 'الدفعات';

  @override
  String get debtOpen => 'مفتوحة';

  @override
  String get debtSettledSection => 'مسددة';

  @override
  String get payFromWallet => 'الدفع من المحفظة؟';

  @override
  String get budgetSpentToday => 'أُنفق اليوم';

  @override
  String get budgetDailyLimit => 'الحد اليومي';

  @override
  String budgetLeftToday(String amount) {
    return 'بقي $amount اليوم';
  }

  @override
  String budgetOverToday(String amount) {
    return 'تجاوز بـ $amount اليوم';
  }

  @override
  String budgetLeftMonth(String amount) {
    return 'بقي $amount هذا الشهر';
  }

  @override
  String budgetOverMonth(String amount) {
    return 'تجاوز الميزانية بـ $amount هذا الشهر';
  }

  @override
  String expensesToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مصاريف',
      two: 'مصروفان',
      one: 'مصروف واحد',
      zero: 'لا شيء مسجّل',
    );
    return '$_temp0';
  }

  @override
  String get snooze10 => 'بعد 10 دقائق';

  @override
  String get snooze60 => 'بعد ساعة';

  @override
  String get snooze180 => 'بعد 3 ساعات';

  @override
  String get tomorrowTitle => 'غدًا';

  @override
  String get tomorrowNothing => 'لا شيء مخطط بعد — ازرع بذور الليلة.';

  @override
  String tomorrowHabits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عادات مستحقة',
      two: 'عادتان مستحقتان',
      one: 'عادة واحدة مستحقة',
      zero: 'لا عادات مستحقة',
    );
    return '$_temp0';
  }

  @override
  String tomorrowTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مهام مخططة',
      two: 'مهمتان مخططتان',
      one: 'مهمة واحدة مخططة',
      zero: 'لا مهام',
    );
    return '$_temp0';
  }

  @override
  String get planTomorrow => 'خطّط';

  @override
  String get rateSaved => 'حُفظ سعر الصرف';

  @override
  String get rateCleared => 'أُزيل سعر الصرف';

  @override
  String get rateInvalid => 'هذا ليس سعرًا صالحًا';

  @override
  String get ratesExplainer =>
      'تُستخدم لعرض مبالغ الدولار واليورو بعملتك الافتراضية.';

  @override
  String get settingsMoney => 'المال';

  @override
  String startupProblem(String error) {
    return 'فشلت خطوة عند بدء التشغيل: $error. أعد تشغيل التطبيق؛ إن تكرر ذلك فاحفظ نسخة وأعد التثبيت.';
  }

  @override
  String get channelReminders => 'التذكيرات';

  @override
  String get channelStreak => 'السلسلة';

  @override
  String get channelPomodoro => 'مؤقت التركيز';

  @override
  String remindersStreakHint(String time) {
    return 'عند $time، فقط إن لم يُكسب اليوم بعد';
  }

  @override
  String get decrease => 'أقل';

  @override
  String get increase => 'أكثر';

  @override
  String get remindersDenied =>
      'التذكيرات محظورة لتطبيق حصاد في إعدادات النظام.';

  @override
  String freezeEarnHint(int coins, int days) {
    return 'اكسب $coins عملة عند سلسلة من $days أيام.';
  }

  @override
  String streakSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'السلسلة: $count أيام',
      one: 'السلسلة: يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String xpAmount(int xp) {
    return '$xp نقطة';
  }

  @override
  String get unitDays => 'ي';

  @override
  String get unitHours => 'س';

  @override
  String get unitMinutes => 'د';

  @override
  String projectProgressOf(int done, int total) {
    return '$done من $total';
  }

  @override
  String get cropOptions => 'المزيد';

  @override
  String get clearValue => 'مسح';

  @override
  String get scheduleDailyShort => 'كل يوم';

  @override
  String scheduleEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count أيام',
      two: 'كل يومين',
      one: 'كل يوم',
    );
    return '$_temp0';
  }

  @override
  String scheduleTimesShort(int count, int done) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرات في الأسبوع',
      two: 'مرتان في الأسبوع',
      one: 'مرة في الأسبوع',
    );
    return '$_temp0 · أُنجز $done';
  }

  @override
  String plannedFor(String date) {
    return 'مخطط $date';
  }

  @override
  String get removeAction => 'إزالة';

  @override
  String get checkInFailed => 'لم يُحفظ ذلك. حاول مجددًا.';

  @override
  String activitySemantics(int days, int weeks) {
    return '$days أيام نشطة في آخر $weeks أسبوعًا';
  }

  @override
  String get cropDone => 'أُنجز';

  @override
  String get cropPending => 'لم يُنجز بعد';

  @override
  String get fromWalletToggle => 'من المحفظة';

  @override
  String walletHas(String amount) {
    return 'في المحفظة $amount';
  }

  @override
  String get walletShort => 'الرصيد في المحفظة لا يكفي';

  @override
  String budgetMonthLine(String spent, String budget, String left) {
    return '$spent من $budget · بقي $left';
  }

  @override
  String budgetMonthOver(String spent, String budget, String over) {
    return '$spent من $budget · تجاوز $over';
  }

  @override
  String get editBudget => 'تعديل الميزانية';

  @override
  String get perDay => 'لكل يوم';

  @override
  String get todayEmptyBody => 'اضغط \"سجّل مصروفًا\" لإضافة أول واحد.';

  @override
  String get debtRemindDefault => 'كل يوم عند 7:00 مساءً حتى السداد';

  @override
  String get undoAction => 'تراجع';

  @override
  String get saveFailed => 'لم يُحفظ ذلك. حاول مجددًا.';

  @override
  String get categoryExists => 'توجد فئة بهذا الاسم';

  @override
  String get withdrawToWallet => 'إلى المحفظة';

  @override
  String get budgetExplainer =>
      'حدّك اليومي هو ما تبقّى من الشهر مقسومًا على أيامه المتبقية.';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get appLockTitle => 'قفل Harvest';

  @override
  String get appLockBody => 'اطلب بصمتك أو رمزك أو كلمة سرك قبل فتح التطبيق.';

  @override
  String get appLockUnavailable =>
      'اضبط بصمة أو رمزًا أو كلمة سر على هذا الجهاز أولًا.';

  @override
  String get lockTitle => 'Harvest مقفل';

  @override
  String get lockBody => 'افتح القفل للعودة إلى حقلك.';

  @override
  String get lockReason => 'افتح قفل Harvest';

  @override
  String get lockUnlockAction => 'افتح القفل';

  @override
  String get lockRefused => 'لم يتطابق. حاول مجددًا.';

  @override
  String get lockTooManyTries => 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.';

  @override
  String get lockUnavailable => 'تعذّر على الجهاز عرض نافذة فتح القفل.';

  @override
  String get settingsData => 'بياناتي';

  @override
  String get exportTitle => 'تصدير جدول بيانات';

  @override
  String get exportBody =>
      'كل بذرة وتسجيل ومصروف وحركة في ملف ‎.xlsx واحد، مع المجاميع كمعادلات حيّة.';

  @override
  String get exportAction => 'التصدير إلى التنزيلات';

  @override
  String get exportRunning => 'جارٍ بناء الجدول…';

  @override
  String exportSaved(String path) {
    return 'حُفظ في $path';
  }

  @override
  String get exportFailedPermission =>
      'لم يُسمح لـ Harvest بالكتابة في التنزيلات.';

  @override
  String get exportFailedUnsupported =>
      'التصدير متاح على أندرويد فقط في الوقت الحالي.';

  @override
  String get exportFailed => 'لم يكتمل التصدير. حاول مجددًا.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get restoreAction => 'استرجاع';

  @override
  String reminderRingsIn(String time) {
    return 'يرنّ بعد $time';
  }

  @override
  String get reminderNow => 'يرنّ الآن';

  @override
  String get editExpense => 'تعديل المصروف';

  @override
  String get deleteExpenseTitle => 'حذف هذا المصروف؟';

  @override
  String deleteExpenseBody(String amount) {
    return 'سيُحذف $amount من اليوم، ويُعاد أي سحب من المحفظة تمّ من أجله.';
  }

  @override
  String get archiveTitle => 'الأرشيف';

  @override
  String get archiveEmpty => 'لا شيء في الأرشيف بعد';

  @override
  String get archiveEmptyBody =>
      'البذور التي تؤرشفها تصل إلى هنا، ومعها الملاحظة التي تشرح السبب.';

  @override
  String archiveSheetBody(String title) {
    return 'أرشفة $title. سجلّها يبقى كما هو.';
  }

  @override
  String get archiveNoteLabel => 'لماذا تؤرشفها؟';

  @override
  String get archiveNoteHint => 'أنهيتها — إلى التالية';

  @override
  String get archiveKeepsHistory => 'يحتفظ بكل تسجيل';

  @override
  String archivedOn(String day) {
    return 'أُرشفت في $day';
  }

  @override
  String restoredToField(String title) {
    return 'عادت $title إلى الحقل';
  }

  @override
  String get deleteSeedTitle => 'حذف هذه البذرة؟';

  @override
  String deleteSeedBody(String title) {
    return 'ستختفي $title وكل تسجيلاتها وكل ملاحظاتها نهائيًا. لا رجعة في هذا — أرشفها بدل ذلك إن أردت الاحتفاظ بالسجلّ.';
  }

  @override
  String get deleteSeedSubtitle => 'نهائيًا، بكل سجلّها';

  @override
  String get seedNotesTitle => 'الملاحظات';

  @override
  String get seedNotesSubtitle => 'أين توقّفت اليوم';

  @override
  String get seedNotesSheetSubtitle => 'ملاحظة اليوم، وآخر ملاحظة';

  @override
  String get seedNotesExplainer =>
      'ملاحظة جديدة كل يوم. ملاحظة الأمس تبقى في السجلّ.';

  @override
  String get seedNoteHint => 'توقّفت عند صفحة ١٤٣';

  @override
  String noteForDay(String day) {
    return 'ملاحظة $day';
  }

  @override
  String lastTimeOn(String day) {
    return 'آخر مرة · $day';
  }

  @override
  String get seedHistoryTitle => 'السجلّ';

  @override
  String get seedHistorySheetSubtitle => 'كل يوم، وما كتبته فيه';

  @override
  String seedHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام في السجلّ',
      two: 'يومان في السجلّ',
      one: 'يوم واحد في السجلّ',
      zero: 'لا أيام بعد',
    );
    return '$_temp0';
  }

  @override
  String get seedHistoryEmpty => 'لا سجلّ بعد';

  @override
  String get seedHistoryEmptyBody => 'سجّل مرة واحدة وسيمتلئ هذا.';

  @override
  String get seedGone => 'هذه البذرة لم تعد موجودة';

  @override
  String get seedGoneBody => 'حُذفت، فلم يبقَ ما يُعرض.';

  @override
  String get streakLabel => 'السلسلة';

  @override
  String get bestLabel => 'الأفضل';

  @override
  String get daysLoggedLabel => 'أيام';

  @override
  String get unitsLabel => 'وحدات';

  @override
  String get checkInsLabel => 'تسجيلات';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return '$_temp0';
  }

  @override
  String unitsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وحدات',
      two: 'وحدتان',
      one: 'وحدة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get checkedIn => 'تم التسجيل';

  @override
  String get noteOnlyDay => 'ملاحظة فقط';

  @override
  String runStripLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام نشطة في الأسابيع الثمانية الأخيرة',
      two: 'يومان نشطان في الأسابيع الثمانية الأخيرة',
      one: 'يوم نشط واحد في الأسابيع الثمانية الأخيرة',
      zero: 'لا أيام نشطة في الأسابيع الثمانية الأخيرة',
    );
    return '$_temp0';
  }

  @override
  String get comebackDay1Title => 'حقلك ينتظرك 🌱';

  @override
  String get comebackDay1Body =>
      'يوم هادئ واحد لا أكثر. اسقِ شيئًا واحدًا وتستمر السلسلة.';

  @override
  String get comebackDay3Title => 'ثلاثة أيام بلا سقاية';

  @override
  String get comebackDay3Body => 'التربة ما زالت طيّبة. ابدأ بأسهل بذرة عندك.';

  @override
  String get comebackWeek1Title => 'أسبوع بعيدًا 🌾';

  @override
  String get comebackWeek1Body =>
      'أفضل سلسلة لك ما زالت مسجّلة. تسجيل واحد يبدأ التالية.';

  @override
  String get comebackWeek2Title => 'أسبوعان من الهدوء';

  @override
  String get comebackWeek2Body =>
      'لم يضع شيء — سجلّك في مكانه تمامًا كما تركته.';

  @override
  String get comebackMonth1Title => 'شهر من أرض بور';

  @override
  String get comebackMonth1Body =>
      'لا لوم ولا تعويض. افتح Harvest وازرع شيئًا واحدًا لليوم.';

  @override
  String get comebackMonth2Title => 'ما زلنا هنا متى عدت';

  @override
  String get comebackMonth2Body =>
      'كل بذرة وكل تسجيل وكل رقم ما زال على هاتفك.';

  @override
  String get widgetTitle => 'أداة الشاشة الرئيسية';

  @override
  String get widgetBody =>
      'سلسلتك وحقل اليوم على الشاشة الرئيسية. أضفها من منتقي الأدوات في المشغّل.';

  @override
  String get widgetStreakLabel => 'يوم متتالٍ';

  @override
  String get widgetTasksLabel => 'اليوم';

  @override
  String get widgetEmpty => 'لا شيء مستحق اليوم';

  @override
  String get loadingTagline => 'ازرع يومك.';

  @override
  String get widgetRefresh => 'حدّثها الآن';
}
