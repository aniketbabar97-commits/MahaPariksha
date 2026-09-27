#!/usr/bin/env python3
"""Generates lib/l10n/app_<lang>.arb files for the Rukhsa Flutter app.

English entries carry ARB @-metadata (description) since app_en.arb is the
flutter gen-l10n template; other languages are plain key/value ARB files.
"""
import json
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "app", "lib", "l10n")

# key -> {lang: text}
STRINGS = {
 "appTitle": {
  "en": 'Rukhsa', "ar": 'رخصة', "ur": 'رخصہ', "hi": 'रुखसा', "tl": 'Rukhsa', "ml": 'റുഖ്സ', "bn": 'রুখসা', "ta": 'ருக்ஸா', "fa": 'رخصه', "fr": 'Rukhsa', "zh": 'Rukhsa', "ru": 'Rukhsa',
 },
 "tagline": {
  "en": 'UAE Driving Test', "ar": 'اختبار القيادة في الإمارات', "ur": 'یو اے ای ڈرائیونگ ٹیسٹ', "hi": 'यूएई ड्राइविंग टेस्ट', "tl": 'Pagsusulit sa Pagmamaneho ng UAE', "ml": 'യുഎഇ ഡ്രൈവിംഗ് ടെസ്റ്റ്', "bn": 'ইউএই ড্রাইভিং টেস্ট', "ta": 'யுஏஇ ஓட்டுநர் தேர்வு', "fa": 'آزمون رانندگی امارات', "fr": 'Examen de conduite aux Émirats', "zh": '阿联酋驾驶考试', "ru": 'Экзамен по вождению в ОАЭ',
 },
 "chooseLanguageTitle": {
  "en": 'Choose your language', "ar": 'اختر لغتك', "ur": 'اپنی زبان منتخب کریں', "hi": 'अपनी भाषा चुनें', "tl": 'Pumili ng iyong wika', "ml": 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക', "bn": 'আপনার ভাষা নির্বাচন করুন', "ta": 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்', "fa": 'زبان خود را انتخاب کنید', "fr": 'Choisissez votre langue', "zh": '选择您的语言', "ru": 'Выберите ваш язык',
 },
 "chooseLanguageSubtitle": {
  "en": 'You can change this anytime in Settings', "ar": 'يمكنك تغيير هذا في أي وقت من الإعدادات', "ur": 'آپ اسے کبھی بھی ترتیبات میں تبدیل کر سکتے ہیں', "hi": 'आप इसे कभी भी सेटिंग्स में बदल सकते हैं', "tl": 'Puwede mong baguhin ito anumang oras sa Mga Setting', "ml": 'സെറ്റിംഗ്സിൽ ഇത് എപ്പോൾ വേണമെങ്കിലും മാറ്റാം', "bn": 'আপনি এটি যেকোনো সময় সেটিংসে পরিবর্তন করতে পারেন', "ta": 'இதை அமைப்புகளில் எப்போது வேண்டுமானாலும் மாற்றலாம்', "fa": 'می\u200cتوانید این را در هر زمان از تنظیمات تغییر دهید', "fr": 'Vous pouvez modifier ceci à tout moment dans les paramètres', "zh": '您可以随时在设置中更改此项', "ru": 'Вы можете изменить это в любое время в настройках',
 },
 "continueButton": {
  "en": 'Continue', "ar": 'متابعة', "ur": 'جاری رکھیں', "hi": 'जारी रखें', "tl": 'Magpatuloy', "ml": 'തുടരുക', "bn": 'চালিয়ে যান', "ta": 'தொடரவும்', "fa": 'ادامه', "fr": 'Continuer', "zh": '继续', "ru": 'Продолжить',
 },
 "homeTitle": {
  "en": 'Home', "ar": 'الرئيسية', "ur": 'ہوم', "hi": 'होम', "tl": 'Home', "ml": 'ഹോം', "bn": 'হোম', "ta": 'முகப்பு', "fa": 'خانه', "fr": 'Accueil', "zh": '首页', "ru": 'Главная',
 },
 "categoriesTitle": {
  "en": 'Categories', "ar": 'الفئات', "ur": 'زمرہ جات', "hi": 'श्रेणियाँ', "tl": 'Mga Kategorya', "ml": 'വിഭാഗങ്ങൾ', "bn": 'বিভাগসমূহ', "ta": 'வகைகள்', "fa": 'دسته\u200cبندی\u200cها', "fr": 'Catégories', "zh": '分类', "ru": 'Категории',
 },
 "startPractice": {
  "en": 'Start Practice', "ar": 'ابدأ التدريب', "ur": 'مشق شروع کریں', "hi": 'अभ्यास शुरू करें', "tl": 'Simulan ang Pagsasanay', "ml": 'പരിശീലനം ആരംഭിക്കുക', "bn": 'অনুশীলন শুরু করুন', "ta": 'பயிற்சியைத் தொடங்கு', "fa": 'شروع تمرین', "fr": "Commencer l'entraînement", "zh": '开始练习', "ru": 'Начать практику',
 },
 "questionsCount": {
  "en": '{count} questions', "ar": '{count} سؤال', "ur": '{count} سوالات', "hi": '{count} प्रश्न', "tl": '{count} tanong', "ml": '{count} ചോദ്യങ്ങൾ', "bn": '{count}টি প্রশ্ন', "ta": '{count} கேள்விகள்', "fa": '{count} سؤال', "fr": '{count} questions', "zh": '{count} 道题', "ru": '{count} вопросов',
 },
 "needsVerificationBadge": {
  "en": 'Under review', "ar": 'قيد المراجعة', "ur": 'زیر جائزہ', "hi": 'समीक्षाधीन', "tl": 'Sinusuri pa', "ml": 'അവലോകനത്തിലാണ്', "bn": 'পর্যালোচনাধীন', "ta": 'மறுஆய்வில்', "fa": 'در حال بررسی', "fr": 'En cours de vérification', "zh": '审核中', "ru": 'На проверке',
 },
 "questionLabel": {
  "en": 'Question {current} of {total}', "ar": 'السؤال {current} من {total}', "ur": 'سوال {current} از {total}', "hi": 'प्रश्न {current} / {total}', "tl": 'Tanong {current} ng {total}', "ml": 'ചോദ്യം {current} / {total}', "bn": 'প্রশ্ন {current} এর {total}', "ta": 'கேள்வி {current} / {total}', "fa": 'سؤال {current} از {total}', "fr": 'Question {current} sur {total}', "zh": '第 {current} 题,共 {total} 题', "ru": 'Вопрос {current} из {total}',
 },
 "showExplanation": {
  "en": 'Show explanation', "ar": 'إظهار الشرح', "ur": 'وضاحت دکھائیں', "hi": 'व्याख्या दिखाएं', "tl": 'Ipakita ang paliwanag', "ml": 'വിശദീകരണം കാണിക്കുക', "bn": 'ব্যাখ্যা দেখান', "ta": 'விளக்கத்தைக் காட்டு', "fa": 'نمایش توضیح', "fr": "Afficher l'explication", "zh": '显示解析', "ru": 'Показать объяснение',
 },
 "correctLabel": {
  "en": 'Correct', "ar": 'صحيح', "ur": 'درست', "hi": 'सही', "tl": 'Tama', "ml": 'ശരി', "bn": 'সঠিক', "ta": 'சரி', "fa": 'درست', "fr": 'Correct', "zh": '正确', "ru": 'Правильно',
 },
 "incorrectLabel": {
  "en": 'Incorrect', "ar": 'غير صحيح', "ur": 'غلط', "hi": 'गलत', "tl": 'Mali', "ml": 'തെറ്റ്', "bn": 'ভুল', "ta": 'தவறு', "fa": 'نادرست', "fr": 'Incorrect', "zh": '错误', "ru": 'Неправильно',
 },
 "nextQuestion": {
  "en": 'Next', "ar": 'التالي', "ur": 'اگلا', "hi": 'अगला', "tl": 'Susunod', "ml": 'അടുത്തത്', "bn": 'পরবর্তী', "ta": 'அடுத்தது', "fa": 'بعدی', "fr": 'Suivant', "zh": '下一题', "ru": 'Далее',
 },
 "finishQuiz": {
  "en": 'Finish', "ar": 'إنهاء', "ur": 'ختم کریں', "hi": 'समाप्त करें', "tl": 'Tapusin', "ml": 'പൂർത്തിയാക്കുക', "bn": 'সমাপ্ত করুন', "ta": 'முடி', "fa": 'پایان', "fr": 'Terminer', "zh": '完成', "ru": 'Завершить',
 },
 "retryQuiz": {
  "en": 'Retry', "ar": 'إعادة المحاولة', "ur": 'دوبارہ کوشش کریں', "hi": 'पुनः प्रयास करें', "tl": 'Subukan Muli', "ml": 'വീണ്ടും ശ്രമിക്കുക', "bn": 'আবার চেষ্টা করুন', "ta": 'மீண்டும் முயற்சி', "fa": 'تلاش دوباره', "fr": 'Réessayer', "zh": '重试', "ru": 'Повторить',
 },
 "backToHome": {
  "en": 'Back to Home', "ar": 'العودة للرئيسية', "ur": 'ہوم پر واپس جائیں', "hi": 'होम पर वापस जाएं', "tl": 'Bumalik sa Home', "ml": 'ഹോമിലേക്ക് മടങ്ങുക', "bn": 'হোমে ফিরে যান', "ta": 'முகப்புக்குத் திரும்பு', "fa": 'بازگشت به خانه', "fr": "Retour à l'accueil", "zh": '返回首页', "ru": 'На главную',
 },
 "resultsTitle": {
  "en": 'Results', "ar": 'النتائج', "ur": 'نتائج', "hi": 'परिणाम', "tl": 'Mga Resulta', "ml": 'ഫലങ്ങൾ', "bn": 'ফলাফল', "ta": 'முடிவுகள்', "fa": 'نتایج', "fr": 'Résultats', "zh": '结果', "ru": 'Результаты',
 },
 "yourScore": {
  "en": 'Your score', "ar": 'نتيجتك', "ur": 'آپ کا اسکور', "hi": 'आपका स्कोर', "tl": 'Iyong iskor', "ml": 'നിങ്ങളുടെ സ്കോർ', "bn": 'আপনার স্কোর', "ta": 'உங்கள் மதிப்பெண்', "fa": 'امتیاز شما', "fr": 'Votre score', "zh": '您的得分', "ru": 'Ваш результат',
 },
 "passLabel": {
  "en": 'Pass', "ar": 'ناجح', "ur": 'پاس', "hi": 'उत्तीर्ण', "tl": 'Pasado', "ml": 'പാസ്', "bn": 'উত্তীর্ণ', "ta": 'தேர்ச்சி', "fa": 'قبول', "fr": 'Réussi', "zh": '通过', "ru": 'Сдано',
 },
 "failLabel": {
  "en": 'Not yet - keep practicing', "ar": 'ليس بعد - واصل التدريب', "ur": 'ابھی نہیں - مشق جاری رکھیں', "hi": 'अभी नहीं - अभ्यास जारी रखें', "tl": 'Hindi pa - magpatuloy sa pagsasanay', "ml": 'ഇതുവരെ ഇല്ല - പരിശീലനം തുടരുക', "bn": 'এখনও না - অনুশীলন চালিয়ে যান', "ta": 'இன்னும் இல்லை - பயிற்சியைத் தொடரவும்', "fa": 'هنوز نه - به تمرین ادامه دهید', "fr": 'Pas encore - continuez à vous entraîner', "zh": '还未通过 - 继续练习', "ru": 'Пока нет - продолжайте практиковаться',
 },
 "passMarkNote": {
  "en": 'Most RTA centres require about 60-70% correct to pass', "ar": 'تتطلب معظم مراكز هيئة الطرق والمواصلات حوالي 60-70% إجابات صحيحة للنجاح', "ur": 'زیادہ تر آر ٹی اے مراکز پاس ہونے کے لیے تقریباً 60-70% درست جوابات کا تقاضا کرتے ہیں', "hi": 'अधिकांश आरटीए केंद्रों में उत्तीर्ण होने के लिए लगभग 60-70% सही उत्तर चाहिए', "tl": 'Karamihan sa mga sentro ng RTA ay nangangailangan ng humigit-kumulang 60-70% tamang sagot para pumasa', "ml": 'മിക്ക ആർടിഎ കേന്ദ്രങ്ങളും പാസാകാൻ ഏകദേശം 60-70% ശരി ഉത്തരങ്ങൾ ആവശ്യപ്പെടുന്നു', "bn": 'বেশিরভাগ আরটিএ কেন্দ্রে পাস করতে প্রায় ৬০-৭০% সঠিক উত্তর প্রয়োজন', "ta": 'பெரும்பாலான RTA மையங்கள் தேர்ச்சி பெற சுமார் 60-70% சரியான பதில்களை கோருகின்றன', "fa": 'بیشتر مراکز RTA برای قبولی حدود ۶۰ تا ۷۰ درصد پاسخ درست می\u200cخواهند', "fr": 'La plupart des centres RTA exigent environ 60 à 70 % de bonnes réponses pour réussir', "zh": '大多数RTA考试中心要求答对约60-70%才能通过', "ru": 'Большинству центров RTA требуется около 60-70% правильных ответов для сдачи',
 },
 "settingsTitle": {
  "en": 'Settings', "ar": 'الإعدادات', "ur": 'ترتیبات', "hi": 'सेटिंग्स', "tl": 'Mga Setting', "ml": 'ക്രമീകരണങ്ങൾ', "bn": 'সেটিংস', "ta": 'அமைப்புகள்', "fa": 'تنظیمات', "fr": 'Paramètres', "zh": '设置', "ru": 'Настройки',
 },
 "languageSettings": {
  "en": 'App language', "ar": 'لغة التطبيق', "ur": 'ایپ کی زبان', "hi": 'ऐप की भाषा', "tl": 'Wika ng app', "ml": 'ആപ്പ് ഭാഷ', "bn": 'অ্যাপের ভাষা', "ta": 'பயன்பாட்டு மொழி', "fa": 'زبان برنامه', "fr": "Langue de l'application", "zh": '应用语言', "ru": 'Язык приложения',
 },
 "aboutTitle": {
  "en": 'About Rukhsa', "ar": 'حول رخصة', "ur": 'رخصہ کے بارے میں', "hi": 'रुखसा के बारे में', "tl": 'Tungkol sa Rukhsa', "ml": 'റുഖ്സയെക്കുറിച്ച്', "bn": 'রুখসা সম্পর্কে', "ta": 'ருக்ஸா பற்றி', "fa": 'درباره رخصه', "fr": 'À propos de Rukhsa', "zh": '关于 Rukhsa', "ru": 'О приложении Rukhsa',
 },
 "aboutBody": {
  "en": 'Rukhsa is an offline practice app for the UAE RTA driving theory test. It is an independent study aid and is not affiliated with any government authority.', "ar": 'رخصة تطبيق تدريب غير متصل بالإنترنت لاختبار نظرية القيادة لدى هيئة الطرق والمواصلات في الإمارات. هذا التطبيق أداة دراسية مستقلة وغير تابع لأي جهة حكومية.', "ur": 'رخصہ یو اے ای آر ٹی اے ڈرائیونگ تھیوری ٹیسٹ کے لیے ایک آف لائن پریکٹس ایپ ہے۔ یہ ایک آزاد مطالعاتی معاون ہے اور کسی سرکاری ادارے سے وابستہ نہیں۔', "hi": 'रुखसा यूएई आरटीए ड्राइविंग थ्योरी टेस्ट के लिए एक ऑफलाइन अभ्यास ऐप है। यह एक स्वतंत्र अध्ययन सहायक है और किसी सरकारी प्राधिकरण से संबद्ध नहीं है।', "tl": 'Ang Rukhsa ay isang offline na app para sa pagsasanay sa UAE RTA driving theory test. Isa itong independiyenteng tulong sa pag-aaral at hindi kaakibat ng anumang ahensya ng pamahalaan.', "ml": 'യുഎഇ ആർടിഎ ഡ്രൈവിംഗ് തിയറി ടെസ്റ്റിനുള്ള ഓഫ്\u200cലൈൻ പരിശീലന ആപ്പാണ് റുഖ്സ. ഇത് ഒരു സ്വതന്ത്ര പഠന സഹായിയാണ്, ഏതെങ്കിലും സർക്കാർ അതോറിറ്റിയുമായി ബന്ധമില്ല.', "bn": 'রুখসা ইউএই আরটিএ ড্রাইভিং তত্ত্ব পরীক্ষার জন্য একটি অফলাইন অনুশীলন অ্যাপ। এটি একটি স্বাধীন অধ্যয়ন সহায়ক এবং কোনো সরকারি কর্তৃপক্ষের সাথে সংযুক্ত নয়।', "ta": 'ருக்ஸா என்பது யுஏஇ ஆர்டிஏ ஓட்டுநர் தேற்று தேர்விற்கான ஆஃப்லைன் பயிற்சி பயன்பாடு. இது ஒரு சுயாதீன படிப்பு உதவியாகும், எந்த அரசு அமைப்புடனும் தொடர்பில்லை.', "fa": 'رخصه یک برنامه تمرین آفلاین برای آزمون تئوری رانندگی RTA امارات است. این یک ابزار مطالعه مستقل است و به هیچ نهاد دولتی وابسته نیست.', "fr": "Rukhsa est une application d'entraînement hors ligne pour l'examen théorique de conduite de la RTA des Émirats. C'est un outil d'étude indépendant, non affilié à une autorité gouvernementale.", "zh": 'Rukhsa 是一款用于阿联酋RTA驾驶理论考试的离线练习应用。它是一个独立的学习辅助工具,与任何政府机构均无关联。', "ru": 'Rukhsa - это офлайн-приложение для подготовки к теоретическому экзамену по вождению RTA в ОАЭ. Это независимое учебное пособие, не связанное с какими-либо государственными органами.',
 },
 "exitConfirmTitle": {
  "en": 'Leave quiz?', "ar": 'مغادرة الاختبار؟', "ur": 'کوئز چھوڑیں؟', "hi": 'क्विज़ छोड़ें?', "tl": 'Umalis sa pagsusulit?', "ml": 'ക്വിസ് വിടണോ?', "bn": 'কুইজ ছাড়বেন?', "ta": 'வினாடி வினாவை விட்டு வெளியேறவா?', "fa": 'خروج از آزمون؟', "fr": 'Quitter le quiz ?', "zh": '退出测验?', "ru": 'Покинуть тест?',
 },
 "exitConfirmBody": {
  "en": 'Your progress in this quiz will be lost.', "ar": 'سيتم فقدان تقدمك في هذا الاختبار.', "ur": 'اس کوئز میں آپ کی پیش رفت ضائع ہو جائے گی۔', "hi": 'इस क्विज़ में आपकी प्रगति खो जाएगी।', "tl": 'Mawawala ang iyong progreso sa pagsusulit na ito.', "ml": 'ഈ ക്വിസിലെ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടും.', "bn": 'এই কুইজে আপনার অগ্রগতি হারিয়ে যাবে।', "ta": 'இந்த வினாடி வினாவில் உங்கள் முன்னேற்றம் இழக்கப்படும்.', "fa": 'پیشرفت شما در این آزمون از بین می\u200cرود.', "fr": 'Votre progression dans ce quiz sera perdue.', "zh": '您在本次测验中的进度将会丢失。', "ru": 'Ваш прогресс в этом тесте будет потерян.',
 },
 "yes": {
  "en": 'Yes', "ar": 'نعم', "ur": 'ہاں', "hi": 'हां', "tl": 'Oo', "ml": 'അതെ', "bn": 'হ্যাঁ', "ta": 'ஆம்', "fa": 'بله', "fr": 'Oui', "zh": '是', "ru": 'Да',
 },
 "no": {
  "en": 'No', "ar": 'لا', "ur": 'نہیں', "hi": 'नहीं', "tl": 'Hindi', "ml": 'ഇല്ല', "bn": 'না', "ta": 'இல்லை', "fa": 'خیر', "fr": 'Non', "zh": '否', "ru": 'Нет',
 },
 "cancel": {
  "en": 'Cancel', "ar": 'إلغاء', "ur": 'منسوخ کریں', "hi": 'रद्द करें', "tl": 'Kanselahin', "ml": 'റദ്ദാക്കുക', "bn": 'বাতিল করুন', "ta": 'ரத்துசெய்', "fa": 'لغو', "fr": 'Annuler', "zh": '取消', "ru": 'Отмена',
 },
 "ok": {
  "en": 'OK', "ar": 'موافق', "ur": 'ٹھیک ہے', "hi": 'ठीक है', "tl": 'OK', "ml": 'ശരി', "bn": 'ঠিক আছে', "ta": 'சரி', "fa": 'باشه', "fr": 'OK', "zh": '确定', "ru": 'ОК',
 },
 "practiceAllMistakes": {
  "en": 'Review flagged content', "ar": 'مراجعة المحتوى المُعلَّم', "ur": 'نشان شدہ مواد کا جائزہ لیں', "hi": 'फ़्लैग की गई सामग्री की समीक्षा करें', "tl": 'Suriin ang mga naka-flag na nilalaman', "ml": 'അടയാളപ്പെടുത്തിയ ഉള്ളടക്കം അവലോകനം ചെയ്യുക', "bn": 'চিহ্নিত সামগ্রী পর্যালোচনা করুন', "ta": 'கொடியிடப்பட்ட உள்ளடக்கத்தை மறுஆய்வு செய்யவும்', "fa": 'بازبینی محتوای علامت\u200cگذاری\u200cشده', "fr": 'Revoir le contenu signalé', "zh": '复习标记内容', "ru": 'Повторить отмеченные материалы',
 },
 "translationPendingNote": {
  "en": "This text is shown in English as this language's translation is still pending.", "ar": 'يُعرض هذا النص بالإنجليزية لأن ترجمة هذه اللغة ما زالت قيد الإنجاز.', "ur": 'یہ متن انگریزی میں دکھایا گیا ہے کیونکہ اس زبان کا ترجمہ ابھی زیر التوا ہے۔', "hi": 'यह पाठ अंग्रेज़ी में दिखाया गया है क्योंकि इस भाषा का अनुवाद अभी लंबित है।', "tl": 'Ipinapakita ang tekstong ito sa Ingles dahil nakabinbin pa ang pagsasalin sa wikang ito.', "ml": 'ഈ ഭാഷയുടെ പരിഭാഷ ഇനിയും തീരുമാനമായിട്ടില്ലാത്തതിനാൽ ഈ വാചകം ഇംഗ്ലീഷിൽ കാണിക്കുന്നു.', "bn": 'এই ভাষার অনুবাদ এখনও মুলতুবি থাকায় এই টেক্সটি ইংরেজিতে দেখানো হচ্ছে।', "ta": 'இந்த மொழியின் மொழிபெயர்ப்பு இன்னும் நிலுவையில் இருப்பதால் இந்த உரை ஆங்கிலத்தில் காட்டப்படுகிறது.', "fa": 'چون ترجمه این زبان هنوز در انتظار است، این متن به انگلیسی نمایش داده می\u200cشود.', "fr": 'Ce texte est affiché en anglais car la traduction dans cette langue est encore en attente.', "zh": '由于该语言的翻译尚未完成,此文本以英文显示。', "ru": 'Этот текст отображается на английском языке, так как перевод на этот язык пока не завершён.',
 },
}

LANGS = ["en", "ar", "ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr", "zh", "ru"]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for lang in LANGS:
        data = {"@@locale": lang}
        for key, translations in STRINGS.items():
            data[key] = translations[lang]
            if lang == "en":
                data[f"@{key}"] = {"description": f"UI string: {key}"}
        path = os.path.join(OUT_DIR, f"app_{lang}.arb")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
