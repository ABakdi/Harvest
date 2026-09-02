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
  String get logProgressTitle => 'اسقِ هذا المحصول';

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
  String get questsTitle => 'مهام اليوم';

  @override
  String get questHabits2 => 'أكمل عادتين';

  @override
  String get questHabitsEarly => 'أكمل عادتين قبل 9 صباحًا';

  @override
  String get questProjectUnits20 => 'اسقِ مشاريعك بـ 20 وحدة';

  @override
  String get questTodos2 => 'أنجز مهمتين';

  @override
  String get questActions4 => 'حقق 4 إنجازات';

  @override
  String get claim => 'استلم';

  @override
  String rewardCoins(int count) {
    return '+$count عملة';
  }

  @override
  String get streakSheetTitle => 'سلسلتك';

  @override
  String streakCurrent(int count) {
    return '$count يومًا';
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
    return '$count';
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
  String get pomodoroLogPrompt => 'أحسنت! سجّل تقدمك في الحقل.';

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
  String get notifPrimeTitle => 'محاصيلك تنتظرك 🌾';

  @override
  String get notifPrimeBody =>
      'هذا وقت تسجيلك المعتاد — تسجيل سريع يبقي الحقل أخضر.';

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
  String get remindersMorning => 'مراجعة الصباح';

  @override
  String get remindersEvening => 'طقس خطة المساء';

  @override
  String get remindersStreak => 'تنبيه خطر السلسلة';

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
  String get obGoalTitle => 'التزامك اليومي';

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
  String get statsLifetimeXp => 'الخبرة الكلية';

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
  String get currencyLabel => 'رمز العملة';

  @override
  String get granaryEmpty => 'لا شيء مسجل اليوم. ماذا أنفقت؟';

  @override
  String get repeatSuggestionTitle => 'نفس الأيام الثلاثة الماضية؟';

  @override
  String get logIt => 'سجّله';

  @override
  String get questLogExpenses => 'سجّل مصاريفك';

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
  String get editSeed => 'تعديل البذرة';

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
    return 'ستنتقل «$title» إلى المخزن، ويبقى سجلها محفوظًا.';
  }

  @override
  String get projectDoneTitle => 'اكتمل الحصاد! 🎉';

  @override
  String projectDoneBody(String title, int total) {
    return 'نضجت «$title» تمامًا — سُجل $total. تنتقل إلى المخزن بفخر.';
  }

  @override
  String get toTheBarn => 'إلى المخزن';

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
  String get savingsLabel => 'المدخرات';

  @override
  String get expectedDailyLabel => 'الإنفاق اليومي المتوقع';

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
  String get expenseCurrencyLabel => 'العملة';

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
  String savingsIn(String code) {
    return 'المدخرات · $code';
  }
}
