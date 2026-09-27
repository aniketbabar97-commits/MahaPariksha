// GENERATED FILE - do not edit by hand.
// Source of truth: app/lib/l10n/app_<lang>.arb
// Regenerate with: python3 rukhsa/pipeline/gen_dart_l10n.py
import 'package:flutter/material.dart';

class AppLocalizations {
  final String localeCode;
  const AppLocalizations(this.localeCode);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('ur'),
    Locale('hi'),
    Locale('tl'),
    Locale('ml'),
    Locale('bn'),
    Locale('ta'),
    Locale('fa'),
    Locale('fr'),
    Locale('zh'),
    Locale('ru'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations('en');
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appTitle': 'Rukhsa',
      'tagline': 'UAE Driving Test',
      'chooseLanguageTitle': 'Choose your language',
      'chooseLanguageSubtitle': 'You can change this anytime in Settings',
      'continueButton': 'Continue',
      'homeTitle': 'Home',
      'categoriesTitle': 'Categories',
      'startPractice': 'Start Practice',
      'questionsCount': '{count} questions',
      'needsVerificationBadge': 'Under review',
      'questionLabel': 'Question {current} of {total}',
      'showExplanation': 'Show explanation',
      'correctLabel': 'Correct',
      'incorrectLabel': 'Incorrect',
      'nextQuestion': 'Next',
      'finishQuiz': 'Finish',
      'retryQuiz': 'Retry',
      'backToHome': 'Back to Home',
      'resultsTitle': 'Results',
      'yourScore': 'Your score',
      'passLabel': 'Pass',
      'failLabel': 'Not yet - keep practicing',
      'passMarkNote': 'Most RTA centres require about 60-70% correct to pass',
      'settingsTitle': 'Settings',
      'languageSettings': 'App language',
      'aboutTitle': 'About Rukhsa',
      'aboutBody': 'Rukhsa is an offline practice app for the UAE RTA driving theory test. It is an independent study aid and is not affiliated with any government authority.',
      'exitConfirmTitle': 'Leave quiz?',
      'exitConfirmBody': 'Your progress in this quiz will be lost.',
      'yes': 'Yes',
      'no': 'No',
      'cancel': 'Cancel',
      'ok': 'OK',
      'practiceAllMistakes': 'Review flagged content',
      'translationPendingNote': 'This text is shown in English as this language\'s translation is still pending.',
    },
    'ar': {
      'appTitle': 'رخصة',
      'tagline': 'اختبار القيادة في الإمارات',
      'chooseLanguageTitle': 'اختر لغتك',
      'chooseLanguageSubtitle': 'يمكنك تغيير هذا في أي وقت من الإعدادات',
      'continueButton': 'متابعة',
      'homeTitle': 'الرئيسية',
      'categoriesTitle': 'الفئات',
      'startPractice': 'ابدأ التدريب',
      'questionsCount': '{count} سؤال',
      'needsVerificationBadge': 'قيد المراجعة',
      'questionLabel': 'السؤال {current} من {total}',
      'showExplanation': 'إظهار الشرح',
      'correctLabel': 'صحيح',
      'incorrectLabel': 'غير صحيح',
      'nextQuestion': 'التالي',
      'finishQuiz': 'إنهاء',
      'retryQuiz': 'إعادة المحاولة',
      'backToHome': 'العودة للرئيسية',
      'resultsTitle': 'النتائج',
      'yourScore': 'نتيجتك',
      'passLabel': 'ناجح',
      'failLabel': 'ليس بعد - واصل التدريب',
      'passMarkNote': 'تتطلب معظم مراكز هيئة الطرق والمواصلات حوالي 60-70% إجابات صحيحة للنجاح',
      'settingsTitle': 'الإعدادات',
      'languageSettings': 'لغة التطبيق',
      'aboutTitle': 'حول رخصة',
      'aboutBody': 'رخصة تطبيق تدريب غير متصل بالإنترنت لاختبار نظرية القيادة لدى هيئة الطرق والمواصلات في الإمارات. هذا التطبيق أداة دراسية مستقلة وغير تابع لأي جهة حكومية.',
      'exitConfirmTitle': 'مغادرة الاختبار؟',
      'exitConfirmBody': 'سيتم فقدان تقدمك في هذا الاختبار.',
      'yes': 'نعم',
      'no': 'لا',
      'cancel': 'إلغاء',
      'ok': 'موافق',
      'practiceAllMistakes': 'مراجعة المحتوى المُعلَّم',
      'translationPendingNote': 'يُعرض هذا النص بالإنجليزية لأن ترجمة هذه اللغة ما زالت قيد الإنجاز.',
    },
    'ur': {
      'appTitle': 'رخصہ',
      'tagline': 'یو اے ای ڈرائیونگ ٹیسٹ',
      'chooseLanguageTitle': 'اپنی زبان منتخب کریں',
      'chooseLanguageSubtitle': 'آپ اسے کبھی بھی ترتیبات میں تبدیل کر سکتے ہیں',
      'continueButton': 'جاری رکھیں',
      'homeTitle': 'ہوم',
      'categoriesTitle': 'زمرہ جات',
      'startPractice': 'مشق شروع کریں',
      'questionsCount': '{count} سوالات',
      'needsVerificationBadge': 'زیر جائزہ',
      'questionLabel': 'سوال {current} از {total}',
      'showExplanation': 'وضاحت دکھائیں',
      'correctLabel': 'درست',
      'incorrectLabel': 'غلط',
      'nextQuestion': 'اگلا',
      'finishQuiz': 'ختم کریں',
      'retryQuiz': 'دوبارہ کوشش کریں',
      'backToHome': 'ہوم پر واپس جائیں',
      'resultsTitle': 'نتائج',
      'yourScore': 'آپ کا اسکور',
      'passLabel': 'پاس',
      'failLabel': 'ابھی نہیں - مشق جاری رکھیں',
      'passMarkNote': 'زیادہ تر آر ٹی اے مراکز پاس ہونے کے لیے تقریباً 60-70% درست جوابات کا تقاضا کرتے ہیں',
      'settingsTitle': 'ترتیبات',
      'languageSettings': 'ایپ کی زبان',
      'aboutTitle': 'رخصہ کے بارے میں',
      'aboutBody': 'رخصہ یو اے ای آر ٹی اے ڈرائیونگ تھیوری ٹیسٹ کے لیے ایک آف لائن پریکٹس ایپ ہے۔ یہ ایک آزاد مطالعاتی معاون ہے اور کسی سرکاری ادارے سے وابستہ نہیں۔',
      'exitConfirmTitle': 'کوئز چھوڑیں؟',
      'exitConfirmBody': 'اس کوئز میں آپ کی پیش رفت ضائع ہو جائے گی۔',
      'yes': 'ہاں',
      'no': 'نہیں',
      'cancel': 'منسوخ کریں',
      'ok': 'ٹھیک ہے',
      'practiceAllMistakes': 'نشان شدہ مواد کا جائزہ لیں',
      'translationPendingNote': 'یہ متن انگریزی میں دکھایا گیا ہے کیونکہ اس زبان کا ترجمہ ابھی زیر التوا ہے۔',
    },
    'hi': {
      'appTitle': 'रुखसा',
      'tagline': 'यूएई ड्राइविंग टेस्ट',
      'chooseLanguageTitle': 'अपनी भाषा चुनें',
      'chooseLanguageSubtitle': 'आप इसे कभी भी सेटिंग्स में बदल सकते हैं',
      'continueButton': 'जारी रखें',
      'homeTitle': 'होम',
      'categoriesTitle': 'श्रेणियाँ',
      'startPractice': 'अभ्यास शुरू करें',
      'questionsCount': '{count} प्रश्न',
      'needsVerificationBadge': 'समीक्षाधीन',
      'questionLabel': 'प्रश्न {current} / {total}',
      'showExplanation': 'व्याख्या दिखाएं',
      'correctLabel': 'सही',
      'incorrectLabel': 'गलत',
      'nextQuestion': 'अगला',
      'finishQuiz': 'समाप्त करें',
      'retryQuiz': 'पुनः प्रयास करें',
      'backToHome': 'होम पर वापस जाएं',
      'resultsTitle': 'परिणाम',
      'yourScore': 'आपका स्कोर',
      'passLabel': 'उत्तीर्ण',
      'failLabel': 'अभी नहीं - अभ्यास जारी रखें',
      'passMarkNote': 'अधिकांश आरटीए केंद्रों में उत्तीर्ण होने के लिए लगभग 60-70% सही उत्तर चाहिए',
      'settingsTitle': 'सेटिंग्स',
      'languageSettings': 'ऐप की भाषा',
      'aboutTitle': 'रुखसा के बारे में',
      'aboutBody': 'रुखसा यूएई आरटीए ड्राइविंग थ्योरी टेस्ट के लिए एक ऑफलाइन अभ्यास ऐप है। यह एक स्वतंत्र अध्ययन सहायक है और किसी सरकारी प्राधिकरण से संबद्ध नहीं है।',
      'exitConfirmTitle': 'क्विज़ छोड़ें?',
      'exitConfirmBody': 'इस क्विज़ में आपकी प्रगति खो जाएगी।',
      'yes': 'हां',
      'no': 'नहीं',
      'cancel': 'रद्द करें',
      'ok': 'ठीक है',
      'practiceAllMistakes': 'फ़्लैग की गई सामग्री की समीक्षा करें',
      'translationPendingNote': 'यह पाठ अंग्रेज़ी में दिखाया गया है क्योंकि इस भाषा का अनुवाद अभी लंबित है।',
    },
    'tl': {
      'appTitle': 'Rukhsa',
      'tagline': 'Pagsusulit sa Pagmamaneho ng UAE',
      'chooseLanguageTitle': 'Pumili ng iyong wika',
      'chooseLanguageSubtitle': 'Puwede mong baguhin ito anumang oras sa Mga Setting',
      'continueButton': 'Magpatuloy',
      'homeTitle': 'Home',
      'categoriesTitle': 'Mga Kategorya',
      'startPractice': 'Simulan ang Pagsasanay',
      'questionsCount': '{count} tanong',
      'needsVerificationBadge': 'Sinusuri pa',
      'questionLabel': 'Tanong {current} ng {total}',
      'showExplanation': 'Ipakita ang paliwanag',
      'correctLabel': 'Tama',
      'incorrectLabel': 'Mali',
      'nextQuestion': 'Susunod',
      'finishQuiz': 'Tapusin',
      'retryQuiz': 'Subukan Muli',
      'backToHome': 'Bumalik sa Home',
      'resultsTitle': 'Mga Resulta',
      'yourScore': 'Iyong iskor',
      'passLabel': 'Pasado',
      'failLabel': 'Hindi pa - magpatuloy sa pagsasanay',
      'passMarkNote': 'Karamihan sa mga sentro ng RTA ay nangangailangan ng humigit-kumulang 60-70% tamang sagot para pumasa',
      'settingsTitle': 'Mga Setting',
      'languageSettings': 'Wika ng app',
      'aboutTitle': 'Tungkol sa Rukhsa',
      'aboutBody': 'Ang Rukhsa ay isang offline na app para sa pagsasanay sa UAE RTA driving theory test. Isa itong independiyenteng tulong sa pag-aaral at hindi kaakibat ng anumang ahensya ng pamahalaan.',
      'exitConfirmTitle': 'Umalis sa pagsusulit?',
      'exitConfirmBody': 'Mawawala ang iyong progreso sa pagsusulit na ito.',
      'yes': 'Oo',
      'no': 'Hindi',
      'cancel': 'Kanselahin',
      'ok': 'OK',
      'practiceAllMistakes': 'Suriin ang mga naka-flag na nilalaman',
      'translationPendingNote': 'Ipinapakita ang tekstong ito sa Ingles dahil nakabinbin pa ang pagsasalin sa wikang ito.',
    },
    'ml': {
      'appTitle': 'റുഖ്സ',
      'tagline': 'യുഎഇ ഡ്രൈവിംഗ് ടെസ്റ്റ്',
      'chooseLanguageTitle': 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
      'chooseLanguageSubtitle': 'സെറ്റിംഗ്സിൽ ഇത് എപ്പോൾ വേണമെങ്കിലും മാറ്റാം',
      'continueButton': 'തുടരുക',
      'homeTitle': 'ഹോം',
      'categoriesTitle': 'വിഭാഗങ്ങൾ',
      'startPractice': 'പരിശീലനം ആരംഭിക്കുക',
      'questionsCount': '{count} ചോദ്യങ്ങൾ',
      'needsVerificationBadge': 'അവലോകനത്തിലാണ്',
      'questionLabel': 'ചോദ്യം {current} / {total}',
      'showExplanation': 'വിശദീകരണം കാണിക്കുക',
      'correctLabel': 'ശരി',
      'incorrectLabel': 'തെറ്റ്',
      'nextQuestion': 'അടുത്തത്',
      'finishQuiz': 'പൂർത്തിയാക്കുക',
      'retryQuiz': 'വീണ്ടും ശ്രമിക്കുക',
      'backToHome': 'ഹോമിലേക്ക് മടങ്ങുക',
      'resultsTitle': 'ഫലങ്ങൾ',
      'yourScore': 'നിങ്ങളുടെ സ്കോർ',
      'passLabel': 'പാസ്',
      'failLabel': 'ഇതുവരെ ഇല്ല - പരിശീലനം തുടരുക',
      'passMarkNote': 'മിക്ക ആർടിഎ കേന്ദ്രങ്ങളും പാസാകാൻ ഏകദേശം 60-70% ശരി ഉത്തരങ്ങൾ ആവശ്യപ്പെടുന്നു',
      'settingsTitle': 'ക്രമീകരണങ്ങൾ',
      'languageSettings': 'ആപ്പ് ഭാഷ',
      'aboutTitle': 'റുഖ്സയെക്കുറിച്ച്',
      'aboutBody': 'യുഎഇ ആർടിഎ ഡ്രൈവിംഗ് തിയറി ടെസ്റ്റിനുള്ള ഓഫ്‌ലൈൻ പരിശീലന ആപ്പാണ് റുഖ്സ. ഇത് ഒരു സ്വതന്ത്ര പഠന സഹായിയാണ്, ഏതെങ്കിലും സർക്കാർ അതോറിറ്റിയുമായി ബന്ധമില്ല.',
      'exitConfirmTitle': 'ക്വിസ് വിടണോ?',
      'exitConfirmBody': 'ഈ ക്വിസിലെ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടും.',
      'yes': 'അതെ',
      'no': 'ഇല്ല',
      'cancel': 'റദ്ദാക്കുക',
      'ok': 'ശരി',
      'practiceAllMistakes': 'അടയാളപ്പെടുത്തിയ ഉള്ളടക്കം അവലോകനം ചെയ്യുക',
      'translationPendingNote': 'ഈ ഭാഷയുടെ പരിഭാഷ ഇനിയും തീരുമാനമായിട്ടില്ലാത്തതിനാൽ ഈ വാചകം ഇംഗ്ലീഷിൽ കാണിക്കുന്നു.',
    },
    'bn': {
      'appTitle': 'রুখসা',
      'tagline': 'ইউএই ড্রাইভিং টেস্ট',
      'chooseLanguageTitle': 'আপনার ভাষা নির্বাচন করুন',
      'chooseLanguageSubtitle': 'আপনি এটি যেকোনো সময় সেটিংসে পরিবর্তন করতে পারেন',
      'continueButton': 'চালিয়ে যান',
      'homeTitle': 'হোম',
      'categoriesTitle': 'বিভাগসমূহ',
      'startPractice': 'অনুশীলন শুরু করুন',
      'questionsCount': '{count}টি প্রশ্ন',
      'needsVerificationBadge': 'পর্যালোচনাধীন',
      'questionLabel': 'প্রশ্ন {current} এর {total}',
      'showExplanation': 'ব্যাখ্যা দেখান',
      'correctLabel': 'সঠিক',
      'incorrectLabel': 'ভুল',
      'nextQuestion': 'পরবর্তী',
      'finishQuiz': 'সমাপ্ত করুন',
      'retryQuiz': 'আবার চেষ্টা করুন',
      'backToHome': 'হোমে ফিরে যান',
      'resultsTitle': 'ফলাফল',
      'yourScore': 'আপনার স্কোর',
      'passLabel': 'উত্তীর্ণ',
      'failLabel': 'এখনও না - অনুশীলন চালিয়ে যান',
      'passMarkNote': 'বেশিরভাগ আরটিএ কেন্দ্রে পাস করতে প্রায় ৬০-৭০% সঠিক উত্তর প্রয়োজন',
      'settingsTitle': 'সেটিংস',
      'languageSettings': 'অ্যাপের ভাষা',
      'aboutTitle': 'রুখসা সম্পর্কে',
      'aboutBody': 'রুখসা ইউএই আরটিএ ড্রাইভিং তত্ত্ব পরীক্ষার জন্য একটি অফলাইন অনুশীলন অ্যাপ। এটি একটি স্বাধীন অধ্যয়ন সহায়ক এবং কোনো সরকারি কর্তৃপক্ষের সাথে সংযুক্ত নয়।',
      'exitConfirmTitle': 'কুইজ ছাড়বেন?',
      'exitConfirmBody': 'এই কুইজে আপনার অগ্রগতি হারিয়ে যাবে।',
      'yes': 'হ্যাঁ',
      'no': 'না',
      'cancel': 'বাতিল করুন',
      'ok': 'ঠিক আছে',
      'practiceAllMistakes': 'চিহ্নিত সামগ্রী পর্যালোচনা করুন',
      'translationPendingNote': 'এই ভাষার অনুবাদ এখনও মুলতুবি থাকায় এই টেক্সটি ইংরেজিতে দেখানো হচ্ছে।',
    },
    'ta': {
      'appTitle': 'ருக்ஸா',
      'tagline': 'யுஏஇ ஓட்டுநர் தேர்வு',
      'chooseLanguageTitle': 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
      'chooseLanguageSubtitle': 'இதை அமைப்புகளில் எப்போது வேண்டுமானாலும் மாற்றலாம்',
      'continueButton': 'தொடரவும்',
      'homeTitle': 'முகப்பு',
      'categoriesTitle': 'வகைகள்',
      'startPractice': 'பயிற்சியைத் தொடங்கு',
      'questionsCount': '{count} கேள்விகள்',
      'needsVerificationBadge': 'மறுஆய்வில்',
      'questionLabel': 'கேள்வி {current} / {total}',
      'showExplanation': 'விளக்கத்தைக் காட்டு',
      'correctLabel': 'சரி',
      'incorrectLabel': 'தவறு',
      'nextQuestion': 'அடுத்தது',
      'finishQuiz': 'முடி',
      'retryQuiz': 'மீண்டும் முயற்சி',
      'backToHome': 'முகப்புக்குத் திரும்பு',
      'resultsTitle': 'முடிவுகள்',
      'yourScore': 'உங்கள் மதிப்பெண்',
      'passLabel': 'தேர்ச்சி',
      'failLabel': 'இன்னும் இல்லை - பயிற்சியைத் தொடரவும்',
      'passMarkNote': 'பெரும்பாலான RTA மையங்கள் தேர்ச்சி பெற சுமார் 60-70% சரியான பதில்களை கோருகின்றன',
      'settingsTitle': 'அமைப்புகள்',
      'languageSettings': 'பயன்பாட்டு மொழி',
      'aboutTitle': 'ருக்ஸா பற்றி',
      'aboutBody': 'ருக்ஸா என்பது யுஏஇ ஆர்டிஏ ஓட்டுநர் தேற்று தேர்விற்கான ஆஃப்லைன் பயிற்சி பயன்பாடு. இது ஒரு சுயாதீன படிப்பு உதவியாகும், எந்த அரசு அமைப்புடனும் தொடர்பில்லை.',
      'exitConfirmTitle': 'வினாடி வினாவை விட்டு வெளியேறவா?',
      'exitConfirmBody': 'இந்த வினாடி வினாவில் உங்கள் முன்னேற்றம் இழக்கப்படும்.',
      'yes': 'ஆம்',
      'no': 'இல்லை',
      'cancel': 'ரத்துசெய்',
      'ok': 'சரி',
      'practiceAllMistakes': 'கொடியிடப்பட்ட உள்ளடக்கத்தை மறுஆய்வு செய்யவும்',
      'translationPendingNote': 'இந்த மொழியின் மொழிபெயர்ப்பு இன்னும் நிலுவையில் இருப்பதால் இந்த உரை ஆங்கிலத்தில் காட்டப்படுகிறது.',
    },
    'fa': {
      'appTitle': 'رخصه',
      'tagline': 'آزمون رانندگی امارات',
      'chooseLanguageTitle': 'زبان خود را انتخاب کنید',
      'chooseLanguageSubtitle': 'می‌توانید این را در هر زمان از تنظیمات تغییر دهید',
      'continueButton': 'ادامه',
      'homeTitle': 'خانه',
      'categoriesTitle': 'دسته‌بندی‌ها',
      'startPractice': 'شروع تمرین',
      'questionsCount': '{count} سؤال',
      'needsVerificationBadge': 'در حال بررسی',
      'questionLabel': 'سؤال {current} از {total}',
      'showExplanation': 'نمایش توضیح',
      'correctLabel': 'درست',
      'incorrectLabel': 'نادرست',
      'nextQuestion': 'بعدی',
      'finishQuiz': 'پایان',
      'retryQuiz': 'تلاش دوباره',
      'backToHome': 'بازگشت به خانه',
      'resultsTitle': 'نتایج',
      'yourScore': 'امتیاز شما',
      'passLabel': 'قبول',
      'failLabel': 'هنوز نه - به تمرین ادامه دهید',
      'passMarkNote': 'بیشتر مراکز RTA برای قبولی حدود ۶۰ تا ۷۰ درصد پاسخ درست می‌خواهند',
      'settingsTitle': 'تنظیمات',
      'languageSettings': 'زبان برنامه',
      'aboutTitle': 'درباره رخصه',
      'aboutBody': 'رخصه یک برنامه تمرین آفلاین برای آزمون تئوری رانندگی RTA امارات است. این یک ابزار مطالعه مستقل است و به هیچ نهاد دولتی وابسته نیست.',
      'exitConfirmTitle': 'خروج از آزمون؟',
      'exitConfirmBody': 'پیشرفت شما در این آزمون از بین می‌رود.',
      'yes': 'بله',
      'no': 'خیر',
      'cancel': 'لغو',
      'ok': 'باشه',
      'practiceAllMistakes': 'بازبینی محتوای علامت‌گذاری‌شده',
      'translationPendingNote': 'چون ترجمه این زبان هنوز در انتظار است، این متن به انگلیسی نمایش داده می‌شود.',
    },
    'fr': {
      'appTitle': 'Rukhsa',
      'tagline': 'Examen de conduite aux Émirats',
      'chooseLanguageTitle': 'Choisissez votre langue',
      'chooseLanguageSubtitle': 'Vous pouvez modifier ceci à tout moment dans les paramètres',
      'continueButton': 'Continuer',
      'homeTitle': 'Accueil',
      'categoriesTitle': 'Catégories',
      'startPractice': 'Commencer l\'entraînement',
      'questionsCount': '{count} questions',
      'needsVerificationBadge': 'En cours de vérification',
      'questionLabel': 'Question {current} sur {total}',
      'showExplanation': 'Afficher l\'explication',
      'correctLabel': 'Correct',
      'incorrectLabel': 'Incorrect',
      'nextQuestion': 'Suivant',
      'finishQuiz': 'Terminer',
      'retryQuiz': 'Réessayer',
      'backToHome': 'Retour à l\'accueil',
      'resultsTitle': 'Résultats',
      'yourScore': 'Votre score',
      'passLabel': 'Réussi',
      'failLabel': 'Pas encore - continuez à vous entraîner',
      'passMarkNote': 'La plupart des centres RTA exigent environ 60 à 70 % de bonnes réponses pour réussir',
      'settingsTitle': 'Paramètres',
      'languageSettings': 'Langue de l\'application',
      'aboutTitle': 'À propos de Rukhsa',
      'aboutBody': 'Rukhsa est une application d\'entraînement hors ligne pour l\'examen théorique de conduite de la RTA des Émirats. C\'est un outil d\'étude indépendant, non affilié à une autorité gouvernementale.',
      'exitConfirmTitle': 'Quitter le quiz ?',
      'exitConfirmBody': 'Votre progression dans ce quiz sera perdue.',
      'yes': 'Oui',
      'no': 'Non',
      'cancel': 'Annuler',
      'ok': 'OK',
      'practiceAllMistakes': 'Revoir le contenu signalé',
      'translationPendingNote': 'Ce texte est affiché en anglais car la traduction dans cette langue est encore en attente.',
    },
    'zh': {
      'appTitle': 'Rukhsa',
      'tagline': '阿联酋驾驶考试',
      'chooseLanguageTitle': '选择您的语言',
      'chooseLanguageSubtitle': '您可以随时在设置中更改此项',
      'continueButton': '继续',
      'homeTitle': '首页',
      'categoriesTitle': '分类',
      'startPractice': '开始练习',
      'questionsCount': '{count} 道题',
      'needsVerificationBadge': '审核中',
      'questionLabel': '第 {current} 题,共 {total} 题',
      'showExplanation': '显示解析',
      'correctLabel': '正确',
      'incorrectLabel': '错误',
      'nextQuestion': '下一题',
      'finishQuiz': '完成',
      'retryQuiz': '重试',
      'backToHome': '返回首页',
      'resultsTitle': '结果',
      'yourScore': '您的得分',
      'passLabel': '通过',
      'failLabel': '还未通过 - 继续练习',
      'passMarkNote': '大多数RTA考试中心要求答对约60-70%才能通过',
      'settingsTitle': '设置',
      'languageSettings': '应用语言',
      'aboutTitle': '关于 Rukhsa',
      'aboutBody': 'Rukhsa 是一款用于阿联酋RTA驾驶理论考试的离线练习应用。它是一个独立的学习辅助工具,与任何政府机构均无关联。',
      'exitConfirmTitle': '退出测验?',
      'exitConfirmBody': '您在本次测验中的进度将会丢失。',
      'yes': '是',
      'no': '否',
      'cancel': '取消',
      'ok': '确定',
      'practiceAllMistakes': '复习标记内容',
      'translationPendingNote': '由于该语言的翻译尚未完成,此文本以英文显示。',
    },
    'ru': {
      'appTitle': 'Rukhsa',
      'tagline': 'Экзамен по вождению в ОАЭ',
      'chooseLanguageTitle': 'Выберите ваш язык',
      'chooseLanguageSubtitle': 'Вы можете изменить это в любое время в настройках',
      'continueButton': 'Продолжить',
      'homeTitle': 'Главная',
      'categoriesTitle': 'Категории',
      'startPractice': 'Начать практику',
      'questionsCount': '{count} вопросов',
      'needsVerificationBadge': 'На проверке',
      'questionLabel': 'Вопрос {current} из {total}',
      'showExplanation': 'Показать объяснение',
      'correctLabel': 'Правильно',
      'incorrectLabel': 'Неправильно',
      'nextQuestion': 'Далее',
      'finishQuiz': 'Завершить',
      'retryQuiz': 'Повторить',
      'backToHome': 'На главную',
      'resultsTitle': 'Результаты',
      'yourScore': 'Ваш результат',
      'passLabel': 'Сдано',
      'failLabel': 'Пока нет - продолжайте практиковаться',
      'passMarkNote': 'Большинству центров RTA требуется около 60-70% правильных ответов для сдачи',
      'settingsTitle': 'Настройки',
      'languageSettings': 'Язык приложения',
      'aboutTitle': 'О приложении Rukhsa',
      'aboutBody': 'Rukhsa - это офлайн-приложение для подготовки к теоретическому экзамену по вождению RTA в ОАЭ. Это независимое учебное пособие, не связанное с какими-либо государственными органами.',
      'exitConfirmTitle': 'Покинуть тест?',
      'exitConfirmBody': 'Ваш прогресс в этом тесте будет потерян.',
      'yes': 'Да',
      'no': 'Нет',
      'cancel': 'Отмена',
      'ok': 'ОК',
      'practiceAllMistakes': 'Повторить отмеченные материалы',
      'translationPendingNote': 'Этот текст отображается на английском языке, так как перевод на этот язык пока не завершён.',
    },
  };

  String _raw(String key) {
    return _strings[localeCode]?[key] ?? _strings['en']?[key] ?? key;
  }

  String get appTitle => _raw('appTitle');

  String get tagline => _raw('tagline');

  String get chooseLanguageTitle => _raw('chooseLanguageTitle');

  String get chooseLanguageSubtitle => _raw('chooseLanguageSubtitle');

  String get continueButton => _raw('continueButton');

  String get homeTitle => _raw('homeTitle');

  String get categoriesTitle => _raw('categoriesTitle');

  String get startPractice => _raw('startPractice');

  String questionsCount(Object count) {
    var s = _raw('questionsCount');
    s = s.replaceAll('{count}', '\$count');
    return s;
  }

  String get needsVerificationBadge => _raw('needsVerificationBadge');

  String questionLabel(Object current, Object total) {
    var s = _raw('questionLabel');
    s = s.replaceAll('{current}', '\$current');
    s = s.replaceAll('{total}', '\$total');
    return s;
  }

  String get showExplanation => _raw('showExplanation');

  String get correctLabel => _raw('correctLabel');

  String get incorrectLabel => _raw('incorrectLabel');

  String get nextQuestion => _raw('nextQuestion');

  String get finishQuiz => _raw('finishQuiz');

  String get retryQuiz => _raw('retryQuiz');

  String get backToHome => _raw('backToHome');

  String get resultsTitle => _raw('resultsTitle');

  String get yourScore => _raw('yourScore');

  String get passLabel => _raw('passLabel');

  String get failLabel => _raw('failLabel');

  String get passMarkNote => _raw('passMarkNote');

  String get settingsTitle => _raw('settingsTitle');

  String get languageSettings => _raw('languageSettings');

  String get aboutTitle => _raw('aboutTitle');

  String get aboutBody => _raw('aboutBody');

  String get exitConfirmTitle => _raw('exitConfirmTitle');

  String get exitConfirmBody => _raw('exitConfirmBody');

  String get yes => _raw('yes');

  String get no => _raw('no');

  String get cancel => _raw('cancel');

  String get ok => _raw('ok');

  String get practiceAllMistakes => _raw('practiceAllMistakes');

  String get translationPendingNote => _raw('translationPendingNote');

}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar', 'ur', 'hi', 'tl', 'ml', 'bn', 'ta', 'fa', 'fr', 'zh', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale.languageCode);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
