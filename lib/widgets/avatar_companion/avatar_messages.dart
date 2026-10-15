// ════════════════════════════════════════════════════════════════════════════
// avatar_messages.dart — Child-friendly Arabic message pools for the
//                         Avatar Companion feature.
//
// Each avatar maps to a personality style that gives messages a distinct voice.
// To add new personality styles or contexts, extend the relevant method here.
// In the future, AI-generated messages can replace the static pools by calling
// a backend endpoint and falling back to these strings when offline.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math';

class AvatarMessages {
  AvatarMessages._();

  static final _rng = Random();

  // ── Personality map: avatar ID → style key ───────────────────────────────
  //
  // Styles: playful | calm | energetic | wise | brave | clever
  //
  // Adding a new avatar? Append its id and choose the nearest personality.
  static const _personalities = <String, String>{
    'rabbit': 'playful',
    'unicorn': 'playful',
    'butterfly': 'calm',
    'panda': 'calm',
    'hamster': 'energetic',
    'koala': 'calm',
    'penguin': 'playful',
    'fox': 'clever',
    'owl': 'wise',
    'turtle': 'calm',
    'bee': 'energetic',
    'dolphin': 'playful',
    'otter': 'playful',
    'sloth': 'calm',
    'bear': 'calm',
    'lion': 'brave',
    'robot': 'clever',
    'dragon': 'brave',
    'queen': 'wise',
    'king': 'wise',
  };

  static String _style(String? id) => _personalities[id] ?? 'playful';

  static String _pick(List<String> items) =>
      items[_rng.nextInt(items.length)];

  // ── Welcome — shown on home screen after login / data load ───────────────

  static String welcome(String studentName, String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return 'أهلاً $studentName! المعرفة تنتظرك. هيا نبدأ رحلتنا! 📚';
      case 'brave':
        return _pick([
          'مرحباً $studentName! هيا نواجه تحديات اليوم معاً! 💪',
          'أهلاً $studentName! البطل مستعد؟ انطلق! 🦁',
        ]);
      case 'clever':
        return _pick([
          'مرحباً $studentName! عقلك الذكي جاهز للتعلم؟ ✨',
          'أهلاً $studentName! الأذكياء دائماً يتعلمون! هيا! 🦊',
        ]);
      case 'energetic':
        return _pick([
          'مرحباً $studentName! يومٌ مشرق ينتظرنا! هيا! ⚡',
          'واو $studentName! أنا متحمس للتعلم معك اليوم! 🌟',
        ]);
      case 'calm':
        return _pick([
          'أهلاً $studentName! نفساً عميقاً، وهيا نتعلم بهدوء 🌸',
          'مرحباً $studentName! سعيدٌ برؤيتك. هيا نتعلم معاً 😊',
        ]);
      default: // playful
        return _pick([
          'أهلاً $studentName! هل أنت مستعد للتعلم اليوم؟ 🌟',
          'مرحباً $studentName! يومٌ جديد، علمٌ جديد! 🎉',
          'أهلاً $studentName! أنا سعيدٌ برؤيتك! هيا نتعلم! 🥳',
        ]);
    }
  }

  // ── Correct answer — positive encouragement ───────────────────────────────

  static String correct(String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return _pick([
          'ممتاز! هذا هو العقل الذكي الحقيقي! 🦉',
          'أحسنت! أنت تُثبت أنك طالبٌ مجتهد! 📚',
        ]);
      case 'brave':
        return _pick([
          'هكذا! إجابةٌ مثالية من بطلٍ حقيقي! 🦁',
          'قوي! أنت على المسار الصحيح! 💪',
        ]);
      case 'clever':
        return _pick([
          'رائع! ذكاؤك يتألق! ✨',
          'إجابةٌ ذكية جداً! أنت نجم! ⭐',
        ]);
      case 'energetic':
        return _pick([
          'اشتعلتَ! إجابةٌ رائعة! استمر! ⚡',
          'نعم نعم نعم! هذا هو! 🎊',
        ]);
      case 'calm':
        return _pick([
          'أحسنتَ! التركيز يؤتي ثماره دائماً ✨',
          'جميل! هذه هي الإجابة الصحيحة! 🌸',
        ]);
      default: // playful
        return _pick([
          'رائع جداً! هذه إجابةٌ صحيحة! 🎉',
          'يا هلا! أنتَ بطلٌ صغير! 🌟',
          'واو! أحسنتَ! أنا فخورٌ بك! 🥳',
          'ممتاز! استمر هكذا! 🎊',
        ]);
    }
  }

  // ── Incorrect answer — supportive, never discouraging ────────────────────

  static String incorrect(String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return _pick([
          'الأخطاء بداية الحكمة. انظر إلى الإجابة الصحيحة! 🦉',
          'لا بأس! كل خطأٍ يُعلّمنا درساً جديداً 📚',
        ]);
      case 'brave':
        return _pick([
          'البطل لا ييأس! تعلّم وانطلق! 🦁',
          'شجاعتك في المحاولة تستحق الإعجاب! 💪',
        ]);
      case 'clever':
        return _pick([
          'الأذكياء يتعلمون من الأخطاء! هيا! 🦊',
          'قريبٌ جداً! انظر إلى الحل وستفهم! ✨',
        ]);
      case 'energetic':
        return _pick([
          'لا يهمّ! الطاقة في المحاولة مجدداً! ⚡',
          'هيا! الخطأ لن يوقفنا! 💫',
        ]);
      case 'calm':
        return _pick([
          'لا تقلق، الخطأ طريقٌ للتعلم. خذ وقتك! 🌸',
          'هدوء... اقرأ الإجابة الصحيحة بتمعّن 😊',
        ]);
      default: // playful
        return _pick([
          'لا بأس! كل خطأٍ درسٌ جميل! 💫',
          'حاول مرة أخرى، أنت تستطيع! 🌟',
          'اقرأ الإجابة الصحيحة، ستتعلم منها! 📖',
          'لا تيأس! النجاح يحتاج مثابرة! 💪',
        ]);
    }
  }

  // ── Hint introduction — avatar introduces the hint ───────────────────────

  static String hint(String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return _pick([
          'دعني أُضيء لك طريق الإجابة! 💡',
          'تلميحٌ من صديقك الحكيم! 🦉💡',
        ]);
      case 'brave':
        return _pick([
          'البطل الذكي يستخدم التلميح عند الحاجة! 💡',
          'ها هو تلميحٌ يساعدك على النصر! 🦁💡',
        ]);
      case 'clever':
        return _pick([
          'تلميحٌ لعقلٍ ذكي مثلك! 🦊💡',
          'ها هو تلميحٌ لتكتشف الإجابة! 💡✨',
        ]);
      case 'energetic':
        return _pick([
          'تلميح جاهز! استخدمه وانطلق! 💡⚡',
          'ها هو! تلميحٌ رائع لك! 🌟💡',
        ]);
      case 'calm':
        return _pick([
          'هذا التلميح سيساعدك بهدوء 💡🌸',
          'خذ هذا التلميح واقرأه بتمعّن 💡',
        ]);
      default: // playful
        return _pick([
          'ها هو تلميحٌ يساعدك! 💡',
          'لا تخجل من التلميح! هو هنا لمساعدتك 😊💡',
          'تلميحٌ سحري لك! 💡🌟',
          'هيا نكشف التلميح معاً! 🎉💡',
        ]);
    }
  }

  // ── Lesson / quiz completion ──────────────────────────────────────────────

  static String completion(String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return _pick([
          'أحسنت! أضفتَ معرفةً جديدة لعقلك! 🦉🌟',
          'لقد أتممتَ الدرس. المعرفة تزداد مع كل درس! 📚',
        ]);
      case 'brave':
        return _pick([
          'بطلٌ حقيقي! أكملتَ الدرس بنجاح! 🦁🏆',
          'هكذا تكون الشجاعة في التعلم! 💪🌟',
        ]);
      case 'clever':
        return _pick([
          'الذكي يُكمل ما بدأه! وقد فعلتَ ذلك! 🦊🌟',
          'ممتاز! عقلٌ ذكي في درسٍ مكتمل! ✨',
        ]);
      case 'energetic':
        return _pick([
          'رائع رائع رائع! أكملتَ الدرس! ⚡🎉',
          'انتهيتَ بقوة! أنت لا يمكن إيقافك! 🌟⚡',
        ]);
      case 'calm':
        return _pick([
          'لقد أتممتَ الدرس بشكل جميل. أنا فخورٌ بك! ✨',
          'هدوءٌ وثبات أوصلاك للنهاية. أحسنت! 🌸',
        ]);
      default: // playful
        return _pick([
          'واو! أكملتَ الدرس! أنت بطل! 🎉',
          'يا هلا! درسٌ مكتمل وأنت رائع! 🌟',
          'هيا هيا! لقد أنجزتَ شيئاً رائعاً! 🥳',
          'ممتاز! درسٌ آخر في جيبك! 🎊',
        ]);
    }
  }

  // ── Adaptive quiz result — personalized by score + student name ──────────

  static String quizResult(String? avatarId, int score, String studentName) {
    final name = studentName.trim().isNotEmpty ? studentName : 'طالبي';
    if (score >= 80) {
      switch (_style(avatarId)) {
        case 'wise':
          return 'أحسنت يا $name! نتيجةٌ تعكس عقلاً متفوقاً! 🦉🌟';
        case 'brave':
          return 'أحسنت يا $name! بطلٌ حقيقي أحرز هذه النتيجة! 🦁🏆';
        case 'clever':
          return 'ذكيٌّ جداً يا $name! نتيجةٌ رائعة تستحق الإعجاب! 🦊✨';
        case 'energetic':
          return 'واو يا $name! اشتعلتَ في هذا الاختبار! ⚡🎉';
        case 'calm':
          return 'جميل يا $name! تعلّمتَ بهدوءٍ وأثمرتَ! 🌸🌟';
        default: // playful
          return _pick([
            'أحسنت يا $name! لقد أكملتَ هذا الاختبار بنجاح! استمر في التقدم! 🌟',
            'رائع يا $name! نتيجةٌ مميزة! أنا فخورٌ بك جداً! 🎉',
          ]);
      }
    } else if (score >= 60) {
      return _pick([
        'عملٌ جيد يا $name! 👍 أنت في الطريق الصحيح. حاول مجدداً لتتحسن أكثر!',
        'أحسنت يا $name! المزيد من المثابرة يوصلك للقمة! 📚',
      ]);
    } else if (score >= 40) {
      return _pick([
        'لا بأس يا $name! 💪 كل محاولة تُعلّمنا شيئاً جديداً. هيا نحاول مرة أخرى!',
        'أنت تتعلم يا $name! الاستمرار هو المفتاح! 🌱',
      ]);
    }
    return _pick([
      'يا $name، لا تستسلم! 🌱 كل محاولة تقودك نحو النجاح!',
      'استمر يا $name! التعلم رحلةٌ جميلة تحتاج مثابرة! 💫',
    ]);
  }

  // ── Rewards — points / badges / level-up ─────────────────────────────────

  static String reward(String? avatarId) {
    switch (_style(avatarId)) {
      case 'wise':
        return _pick([
          'كل نقطة تقربك من القمة! 📚⭐',
          'جهدٌ يستحق التكريم! مبروك نقاطك! 🦉',
        ]);
      case 'brave':
        return _pick([
          'البطل يكسب النقاط بجدارة! 🦁🏆',
          'هذه النقاط لجهدٍ حقيقي! أحسنت! 💪',
        ]);
      case 'clever':
        return _pick([
          'ذكاؤك يجلب لك النقاط! 🦊⭐',
          'النقاط الذكية لطالبٍ ذكي! 🌟',
        ]);
      case 'energetic':
        return _pick([
          'نقاط جديدة! أنت تتقدم بسرعة! ⚡🌟',
          'ياه! نقاطٌ جديدة! هيا نجمع المزيد! 🎊',
        ]);
      case 'calm':
        return _pick([
          'بهدوءٍ وثبات تجمع النقاط. ممتاز! 🌸',
          'كل نقطة دليلٌ على جهدك. أحسنت! ✨',
        ]);
      default: // playful
        return _pick([
          'يا هلا! نقاطٌ جديدة لك! 🌟',
          'اجمع نقاطك واوصل للقمة! ⭐🎉',
          'ممتاز! نقاطٌ تستحقها! 🥳',
          'أنت تتقدم! هيا نجمع أكثر! 🚀',
        ]);
    }
  }
}
