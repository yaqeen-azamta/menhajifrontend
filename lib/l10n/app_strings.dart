// Centralized Arabic strings.
// To add English support later, create AppStringsEn with the same fields
// and swap based on the active locale.
class AppStrings {
  AppStrings._();

  // ── General ────────────────────────────────────────────────
  static const appName = 'منهاجي';
  static const retry = 'إعادة المحاولة';
  static const goBack = 'رجوع';
  static const continueBtn = 'متابعة';
  static const finish = 'إنهاء 🎉';
  static const cancel = 'إلغاء';
  static const loading = 'جارٍ التحميل...';

  // ── Login ──────────────────────────────────────────────────
  static const loginWelcome = 'أهلاً';
  static const loginSignUpTitle = 'إنشاء حساب للأهل';
  static const loginTab = 'تسجيل الدخول';
  static const signUpTab = 'إنشاء حساب';
  static const loginBtn = 'تسجيل الدخول';
  static const signUpBtn = 'إنشاء حساب';
  static const parentName = 'اسم ولي الأمر';
  static const emailHint = 'البريد الإلكتروني';
  static const passwordHint = 'كلمة المرور';
  static const loginParentsOnly =
      'للوالدين فقط — سيحصل الأطفال على ملفاتهم الشخصية قريباً.';
  static const loginFillFields = 'يرجى ملء جميع الحقول';
  static const loginEnterName = 'يرجى إدخال الاسم';
  static const loginConnectionError = 'خطأ في الاتصال. يرجى المحاولة مجدداً.';

  // ── Profiles ───────────────────────────────────────────────
  static const profilesGreeting = 'أهلاً';
  static const profilesWhoLearning = 'من يتعلم اليوم؟';
  static const profilesAddKid = 'إضافة طفل';
  static const profilesAddKidBtn = '+ إضافة طفل';
  static const profilesNoKids =
      'لم يتم إضافة أطفال بعد.\nاضغط "إضافة طفل" لإنشاء أول ملف.';
  static const profilesAddKidTitle = 'إضافة طفل';
  static const profilesAddKidSubtitle = 'أنشئ حساباً تعليمياً لطفلك.';
  static const profilesChildName = 'اسم الطفل الكامل';
  static const profilesChildEmail = 'البريد الإلكتروني';
  static const profilesChildPassword = 'كلمة المرور (6 أحرف كحد أدنى)';
  static const profilesGradeLevel = 'المرحلة الدراسية';
  static const profilesChooseAvatar = 'اختر الصورة الرمزية';
  static const profilesCreateAccount = 'إنشاء الحساب';
  static const profilesNameRequired = 'الاسم مطلوب';
  static const profilesInvalidEmail = 'أدخل بريداً إلكترونياً صحيحاً';
  static const profilesPasswordTooShort =
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
  static const profilesCreateFailed = 'تعذر إنشاء الحساب. حاول مجدداً.';
  static const profilesParentNotFound =
      'تعذر التعرف على ولي الأمر. يرجى إعادة تسجيل الدخول.';

  // ── Home ───────────────────────────────────────────────────
  static String homeGreeting(String name) => 'أهلاً $name! 👋';
  static const homeSubtitle = 'هل أنت مستعد لتعلم شيء ممتع اليوم؟';
  static const homeDailyGoal = 'هدف اليوم';
  static const homeNoLessons = 'لا دروس بعد';
  static String homeLessonsProgress(int done, int total) =>
      '$done / $total دروس';
  static const homeAllLessonsComplete = '🎉 تم إكمال جميع الدروس';
  static const homeKeepGoing = 'استمر! أنت تستطيع!';
  static const homeAllDone = '🎉 انتهيت من جميع الدروس! رائع!';
  static const homeLessonsSoon = 'ستظهر دروسك هنا قريباً!';
  static const homeNextUp = 'الدرس التالي';
  static String homeNextMeta(int semester, int order) =>
      'الفصل $semester · الدرس $order';
  static const homeStart = 'ابدأ';
  static String homeStartLesson(String title) => 'ابدأ $title';
  static const homeWelcomeMsg =
      '🎉 مرحباً! ستظهر دروسك هنا بمجرد إعدادها من قبل المعلم.';
  static const homeSubjects = 'المواد الدراسية';
  static const homeNoSubjects = 'لا توجد مواد مخصصة لهذا الصف بعد.';
  static const homeLessonPath = 'مسار الدروس';
  static const homeMyRewards = 'مكافآتي';
  static const homeSelectChild = 'يرجى اختيار ملف طفل للمتابعة.';
  static const homeSessionExpired =
      'انتهت الجلسة. يرجى اختيار ملف الطالب مجدداً.';
  static const homeSwitchProfile = 'تغيير الملف';
  static String homeLessonsDone(int done, int total) => '$done/$total مكتمل';

  // ── Path ───────────────────────────────────────────────────
  static const pathTitle = '🗺 مسار الدروس';
  static const pathMath = '🔢 مسار الرياضيات';
  static const pathReading = '📖 مسار القراءة';
  static const pathScience = '🔬 مسار العلوم';
  static const pathNoLessons = 'لا توجد دروس متاحة بعد.';
  static const pathCompleted = 'مكتمل';
  static const pathTapToStart = 'اضغط للبدء!';
  static const pathLocked = 'مقفل';

  // ── Lesson ─────────────────────────────────────────────────
  static const lessonNotFound = 'لم يتم العثور على الدرس.';
  static const lessonStepWelcomeTitle = 'مرحباً!';
  static String lessonStepWelcomeBody(String title, String objectives) =>
      'مرحباً بك في: $title. $objectives';
  static const lessonStepLearnTitle = 'تعلّم';
  static const lessonStepSpeakTitle = 'حاول قوله!';
  static const lessonStepSpeakBody =
      'اضغط على الميكروفون واقرأ الدرس بصوت عالٍ!';
  static const lessonTapToHear = 'اضغط للاستماع';
  static String lessonYouSaid(String text) => 'قلت: "$text"';
  static const lessonMicPermission =
      'يرجى السماح بالوصول إلى الميكروفون. يمكنك المتابعة!';
  static const lessonViewQuestions = 'عرض الأسئلة 📖';
  static const lessonAudioNotAvailable = 'الصوت غير متاح';
  static const lessonAudioFailed = 'تعذر تحميل الصوت';

  // ── Questions ──────────────────────────────────────────────
  static const questionLabel = 'السؤال';
  static const questionWriteHint = 'اكتب إجابتك...';
  static const questionDrawFirst = 'يرجى الرسم أولاً! ✏️';
  static const questionTraceInstruction = 'تتبع بعناية';
  static const questionNoQuestions = 'لم يتم العثور على أسئلة.';
  static const questionCorrect = 'إجابة صحيحة ✅';
  static const questionWrong = 'إجابة خاطئة ❌';
  static const quizDialogTitle = 'هل تريد حل الاختبار؟';
  static const quizDialogContent = 'هل تريد حل الاختبار الآن؟';
  static const quizDialogNo = 'لا';
  static const quizDialogYes = 'نعم';

  // ── Hints ──────────────────────────────────────────────────
  static const hintButton = 'تلميح 💡';
  static const hintSheetTitle = 'تلميح';
  static String hintLevelLabel(int level) => 'المستوى $level';
  static const hintNextLevel = 'تلميح أقوى';
  static const hintNoMore = 'لا توجد تلميحات أخرى';
  static const hintFailed = 'تعذر الحصول على التلميح';
  static const hintClose = 'إغلاق';
  static String hintRemainingLabel(int n) => 'متبقٍ: $n';

  // ── Quiz ───────────────────────────────────────────────────
  static const quizLoadingMsg = 'جارٍ تحضير الأسئلة... 🍳';
  static const quizNoQuestions = 'لم يتم العثور على أسئلة.';
  static const quizOutOfHearts = 'نفدت القلوب!';
  static const quizOutOfHeartsMsg =
      'لا تقلق، يمكنك تجربة هذا الدرس مجدداً.';
  static const quizTryAgain = 'حاول مجدداً';
  static const quizQuitTitle = 'الخروج من الاختبار؟';
  static const quizQuitContent = 'ستفقد تقدمك في هذا الاختبار.';
  static const quizKeepGoing = 'استمر';
  static const quizQuit = 'خروج';

  // ── Feedback panel ─────────────────────────────────────────
  static const feedbackCorrect = 'صحيح!';
  static const feedbackWrong = 'ليس تماماً!';
  static String feedbackCorrectAnswer(String answer) =>
      'الإجابة الصحيحة: $answer';

  // ── Rewards ────────────────────────────────────────────────
  static const rewardsBackHome = 'العودة للرئيسية';
  static const rewardsComplete = 'اكتمل الاختبار!';
  static const rewardsYourRewards = 'مكافآتك';
  static const rewardsCompletePrompt =
      'أكمل اختباراً لتكسب النجوم والنقاط!';
  static const rewardsCorrect = 'صحيح';
  static const rewardsScore = 'النتيجة';
  static const rewardsXp = 'النقاط المكتسبة';

  // ── Tracing ────────────────────────────────────────────────
  static const tracingTitle = 'تدريب الكتابة';
  static const tracingBanner = 'اتبع الخطوط المنقطة وتتبع كل حرف!';
  static const tracingDrawFirst = 'ارسم شيئاً أولاً!';
  static const tracingClear = 'مسح';
  static const tracingCheck = 'تحقق من عملي';

  // ── Login (extended) ───────────────────────────────────────
  static const loginNoAccount = 'ليس لديك حساب؟';
  static const loginCreateAccount = 'إنشاء حساب جديد';

  // ── Role Selection ─────────────────────────────────────────
  static const roleSelectTitle = 'اختر دورك';
  static const roleSelectSubtitle = 'سجّل كـ...';
  static const roleStudent = 'طالب';
  static const roleParent = 'ولي أمر';
  static const roleTeacher = 'معلم';

  // ── Student Register ───────────────────────────────────────
  static const studentRegTitle = 'تسجيل طالب';
  static const studentName = 'اسم الطالب';
  static const studentGradeLevel = 'المرحلة الدراسية';
  static const studentSchool = 'المدرسة';
  static const studentChooseAvatar = 'اختر الصورة الرمزية';
  static const studentGradePrefix = 'الصف';

  // ── Parent Register ────────────────────────────────────────
  static const parentRegTitle = 'تسجيل ولي الأمر';
  static const parentPhone = 'رقم الهاتف';

  // ── Teacher Register ───────────────────────────────────────
  static const teacherRegTitle = 'تسجيل معلم';
  static const teacherName = 'اسم المعلم';
  static const teacherSchool = 'المدرسة';
  static const teacherSubject = 'المادة';
  static const teacherSpecialization = 'التخصص';

  // ── Teacher Dashboard ──────────────────────────────────────
  static const teacherDashTitle = 'لوحة المعلم';
  static const teacherDashWelcome = 'أهلاً، معلمنا الفاضل!';
  static const teacherDashComingSoon = 'لوحة التحكم قيد التطوير';
  static const teacherDashLogout = 'تسجيل الخروج';

  // ── Common Register ────────────────────────────────────────
  static const registerBtn = 'تسجيل';
  static const registerFillFields = 'يرجى ملء جميع الحقول';
  static const registerSuccess = 'تم التسجيل بنجاح!';
  static const registerFailed = 'تعذر التسجيل. حاول مجدداً.';
  static const fullNameHint = 'الاسم الكامل';

  // ── Avatar ─────────────────────────────────────────────────
  /// Label shown under an available-but-not-chosen avatar.
  static const avatarAvailable = '✅ متاح';
  /// Label shown under the currently active avatar.
  static const avatarSelected = '✓ مختار';
  /// Label shown under a locked avatar: "🔒 200 نقطة"
  static String avatarRequiredPoints(int pts) => '🔒 $pts نقطة';
  /// Full snackbar copy when a locked avatar is tapped.
  static String avatarUnlockRequires(String name, int pts) =>
      'اجمع $pts نقطة لفتح $name';
  /// Snackbar when a new avatar is unlocked via point accumulation.
  static String avatarNewUnlock(String name) => '🎉 تم فتح شخصية جديدة: $name!';
  /// Snackbar after successfully changing the active avatar.
  static const avatarChanged = '✅ تم تغيير الصورة الرمزية';
  /// Snackbar when the user taps the avatar they already have.
  static const avatarAlreadyActive = 'هذه هي صورتك الرمزية الحالية';
  /// Subtitle inside the avatar collection card.
  static const avatarSelectHint = 'اضغط على شخصية مفتوحة لاختيارها';

  // ── Reading Assessment ─────────────────────────────────────
  static const readingTitle = 'تقييم القراءة';
  static const readingInstruction = 'اقرأ الفقرة التالية بصوت عالٍ:';
  static const readingStart = 'ابدأ القراءة 🎙️';
  static const readingStop = 'إيقاف التسجيل ⏹';
  static const readingProcessing = 'جارٍ تحليل قراءتك...';
  static const readingTryAgain = 'حاول مجدداً 🔄';
  static const readingAccuracyLabel = 'دقة القراءة';
  static const readingResultTitle = 'تفاصيل القراءة';
  static const readingOriginalLabel = 'النص الأصلي';
  static const readingRecognizedLabel = 'ما سمعته';
  static const readingWordCorrect = 'صحيح';
  static const readingWordIncorrect = 'خطأ';
  static const readingWordMissing = 'مفقود';
  static const readingPermissionDenied =
      'يرجى السماح بالوصول إلى الميكروفون لتتمكن من القراءة.';
  static const readingNoText = 'لم يتم تحديد نص للقراءة. يرجى المحاولة مجدداً.';
  static const readingUploadError =
      'حدث خطأ أثناء تحليل قراءتك. يرجى المحاولة مجدداً.';
  static const readingLoadError =
      'تعذر تحميل نص القراءة. يرجى المحاولة مجدداً.';
  static String readingAccuracyPct(int pct) => '$pct%';
  static String readingTimer(String mm, String ss) => '$mm:$ss';
  // Grade labels shown beneath the accuracy arc
  // Feedback tiers match PronunciationService.feedbackFor():
  //   ≥ 90 → Excellent  |  ≥ 70 → Good  |  ≥ 50 → Needs Work  |  < 50 → Try Again
  static const readingGradeExcellent  = 'ممتاز! 🌟';
  static const readingGradeGood       = 'جيد! 👍';
  static const readingGradeNeedsWork  = 'يحتاج تحسين 💪';
  static const readingGradeTryAgain   = 'حاول مرة أخرى ⚡';

  // ── Letter-level analysis section ─────────────────────────
  static const readingLetterAnalysisTitle  = 'تحليل الحروف';
  static const readingWrongLettersLabel    = 'أخطاء النطق';
  static const readingMissingLettersLabel  = 'حروف مفقودة';
  static const readingExtraLettersLabel    = 'حروف زائدة';

  // ── Adaptive Quiz ──────────────────────────────────────────
  static const adaptiveQuizLoading = 'جارٍ تحضير الاختبار الذكي... 🧠';
  static const adaptiveQuizNoQuestions = 'لا توجد أسئلة في هذا الاختبار.';
  static const adaptiveQuizMinAnswers =
      'يجب الإجابة على نصف الأسئلة على الأقل قبل الإرسال.';
  static const adaptiveQuizSubmitting = 'جارٍ إرسال إجاباتك...';

  // Hint strings (adaptive quiz)
  static const adaptiveHintButton = 'تلميح 💡';
  static const adaptiveHintExhausted = 'لا تلميحات أخرى 🔒';
  static const adaptiveHintLimit429 = 'وصلت إلى الحد الأقصى من التلميحات';
  static const adaptiveHintFailed = 'تعذر الحصول على التلميح. حاول مجدداً.';
  static const adaptiveHintStronger = 'تلميح أقوى';
  static const adaptiveHintClose = 'إغلاق';
  static const adaptiveHintTitle = 'تلميح';
  static String adaptiveHintRemainingPerQ(int n) => 'متبقٍ للسؤال: $n';
  static String adaptiveHintRemainingTotal(int n) => 'متبقٍ للاختبار: $n';

  // Result screen
  static const adaptiveResultTitle = 'نتيجة الاختبار الذكي';
  static const adaptiveResultScore = 'النتيجة';
  static const adaptiveResultCorrect = 'صحيح';
  static const adaptiveResultIncorrect = 'خطأ';
  static const adaptiveResultTotal = 'الإجمالي';
  static const adaptiveResultDifficulty = 'مستوى الصعوبة';
  static const adaptiveResultSkillsTitle = 'مهارات محدّثة';
  static const adaptiveResultRetry = 'محاولة أخرى';
  static const adaptiveResultHome = 'العودة للرئيسية';

  static String adaptiveResultEncouragement(int score) {
    if (score >= 80) return 'أحسنت! ممتاز! 🌟';
    if (score >= 60) return 'عمل جيد! استمر! 💪';
    if (score >= 40) return 'لا بأس، تمرّن أكثر وستتحسن! 📚';
    return 'استمر بالتدريب، أنت تستطيع! 🌱';
  }

  static String adaptiveResultSkillTip(List<String> skills) {
    if (skills.isEmpty) return '';
    return 'استمر بالتدريب على: ${skills.join(' و ')}';
  }

  // Network / error messages (adaptive quiz)
  static const adaptiveNetworkError =
      'تعذر الاتصال. تحقق من الإنترنت وأعد المحاولة.';
  static const adaptiveServerError = 'خطأ في الخادم. يرجى المحاولة لاحقاً.';
  static const adaptiveUnauthorized =
      'انتهت الجلسة. يرجى تسجيل الدخول مجدداً.';
}
