/// UAE road-sign reference library.
///
/// Shapes/colors follow the real UAE (RTA / MUTCD-influenced) sign
/// conventions used across the country's driving-theory handbooks:
///  - Mandatory (instruction) signs: blue circle, white symbol.
///  - Warning/hazard signs: yellow/red triangle, point up, black symbol.
///  - Prohibitory signs: white circle, red border, black symbol/diagonal bar.
///  - Informatory/guide signs: blue or green rectangle, white symbol/text.
///  - A small number of unique shapes are reserved by convention (octagon
///    for STOP, inverted triangle for GIVE WAY, circle with horizontal bar
///    for NO ENTRY) and are modelled as their own [RoadSignShape] values.
///
/// This is a study reference, not a scan of the official RTA handbook —
/// names/meanings describe internationally-standard sign meanings that UAE
/// signage follows, consistent with `content/taxonomy.json`'s note that this
/// project is a study organiser, not an official document.
library;

enum RoadSignShape { circle, invertedTriangle, triangle, rectangle, octagon, diamond }

enum RoadSignCategory { mandatory, warning, prohibitory, informatory, priority }

class RoadSign {
  final String id;
  final String category; // matches RoadSignCategory name, for filtering
  final RoadSignShape shape;
  final String primaryColor; // 'red' | 'blue' | 'yellow' | 'white' | 'green' | 'black'
  final String nameEn;
  final String nameAr;
  final String meaningEn;
  final String meaningAr;

  const RoadSign({
    required this.id,
    required this.category,
    required this.shape,
    required this.primaryColor,
    required this.nameEn,
    required this.nameAr,
    required this.meaningEn,
    required this.meaningAr,
  });
}

/// Curated set of 20 real, commonly-tested UAE road signs spanning all four
/// major categories plus the two unique-shape priority signs.
const List<RoadSign> uaeRoadSigns = [
  // --- Priority / unique shapes -------------------------------------------------
  RoadSign(
    id: 'stop',
    category: 'priority',
    shape: RoadSignShape.octagon,
    primaryColor: 'red',
    nameEn: 'Stop',
    nameAr: 'قف',
    meaningEn: 'Come to a complete stop and give way to traffic before proceeding. The only octagonal sign on UAE roads.',
    meaningAr: 'توقف تماماً وأعطِ الأولوية لحركة المرور قبل المتابعة. الإشارة الثُمانية الوحيدة على طرق الإمارات.',
  ),
  RoadSign(
    id: 'give_way',
    category: 'priority',
    shape: RoadSignShape.invertedTriangle,
    primaryColor: 'red',
    nameEn: 'Give Way',
    nameAr: 'أعطِ الأولوية',
    meaningEn: 'Slow down and be ready to stop to let other traffic on the main road pass first.',
    meaningAr: 'قلل سرعتك واستعد للتوقف لإعطاء الأولوية لحركة المرور القادمة من الطريق الرئيسي.',
  ),
  RoadSign(
    id: 'no_entry',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'No Entry',
    nameAr: 'ممنوع الدخول',
    meaningEn: 'A solid red circle with a white horizontal bar: entry is prohibited for all vehicles in this direction.',
    meaningAr: 'دائرة حمراء صلبة مع شريط أبيض أفقي: يُمنع الدخول لجميع المركبات في هذا الاتجاه.',
  ),

  // --- Mandatory (blue circle, white symbol) -------------------------------------
  RoadSign(
    id: 'straight_only',
    category: 'mandatory',
    shape: RoadSignShape.circle,
    primaryColor: 'blue',
    nameEn: 'Straight Ahead Only',
    nameAr: 'المتابعة مباشرة فقط',
    meaningEn: 'Traffic must proceed straight ahead only; no turns are allowed at this point.',
    meaningAr: 'يجب على المركبات المتابعة مباشرة فقط؛ لا يُسمح بالانعطاف عند هذه النقطة.',
  ),
  RoadSign(
    id: 'turn_right_only',
    category: 'mandatory',
    shape: RoadSignShape.circle,
    primaryColor: 'blue',
    nameEn: 'Turn Right Only',
    nameAr: 'الانعطاف يميناً فقط',
    meaningEn: 'Traffic must turn right at this point; going straight or left is not permitted.',
    meaningAr: 'يجب على المركبات الانعطاف يميناً؛ لا يُسمح بالمتابعة مباشرة أو الانعطاف يساراً.',
  ),
  RoadSign(
    id: 'roundabout_ahead_mandatory',
    category: 'mandatory',
    shape: RoadSignShape.circle,
    primaryColor: 'blue',
    nameEn: 'Roundabout — Mandatory Direction',
    nameAr: 'دوار - اتجاه إلزامي',
    meaningEn: 'Circular arrows show traffic must travel around the roundabout in the direction shown.',
    meaningAr: 'الأسهم الدائرية تشير إلى وجوب السير حول الدوار في الاتجاه الموضح.',
  ),
  RoadSign(
    id: 'minimum_speed',
    category: 'mandatory',
    shape: RoadSignShape.circle,
    primaryColor: 'blue',
    nameEn: 'Minimum Speed Limit',
    nameAr: 'الحد الأدنى للسرعة',
    meaningEn: 'Vehicles must maintain at least the speed shown, conditions permitting (common on highway fast lanes).',
    meaningAr: 'يجب على المركبات الحفاظ على السرعة المحددة كحد أدنى، حسب ظروف الطريق (شائعة في المسارات السريعة).',
  ),
  RoadSign(
    id: 'cycle_lane',
    category: 'mandatory',
    shape: RoadSignShape.circle,
    primaryColor: 'blue',
    nameEn: 'Cycle Route / Lane Ahead',
    nameAr: 'مسار دراجات',
    meaningEn: 'A route or lane is reserved for bicycles; motor vehicles must not use it.',
    meaningAr: 'مسار مخصص للدراجات الهوائية؛ يُمنع على المركبات الآلية استخدامه.',
  ),

  // --- Prohibitory (white circle, red border) ------------------------------------
  RoadSign(
    id: 'no_u_turn',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'No U-Turn',
    nameAr: 'ممنوع الانعطاف للخلف',
    meaningEn: 'U-turns are not allowed at this point on the road.',
    meaningAr: 'يُمنع الانعطاف للخلف (يو-تيرن) عند هذه النقطة من الطريق.',
  ),
  RoadSign(
    id: 'no_overtaking',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'No Overtaking',
    nameAr: 'ممنوع التجاوز',
    meaningEn: 'Overtaking other vehicles is prohibited for the stretch of road this sign covers.',
    meaningAr: 'يُمنع تجاوز المركبات الأخرى في الجزء من الطريق الذي تغطيه هذه الإشارة.',
  ),
  RoadSign(
    id: 'no_horn',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'No Horn',
    nameAr: 'ممنوع استخدام المنبه',
    meaningEn: 'Sounding the vehicle horn is prohibited in this area (common near hospitals, mosques, residential zones).',
    meaningAr: 'يُمنع استخدام آلة التنبيه (البوق) في هذه المنطقة (شائعة قرب المستشفيات والمساجد والمناطق السكنية).',
  ),
  RoadSign(
    id: 'no_parking',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'No Parking',
    nameAr: 'ممنوع الوقوف',
    meaningEn: 'Stopping and parking are not allowed here, at any time unless a supplementary plate states otherwise.',
    meaningAr: 'يُمنع التوقف والانتظار هنا في أي وقت ما لم تذكر لوحة إضافية خلاف ذلك.',
  ),
  RoadSign(
    id: 'max_speed_limit',
    category: 'prohibitory',
    shape: RoadSignShape.circle,
    primaryColor: 'red',
    nameEn: 'Maximum Speed Limit',
    nameAr: 'الحد الأقصى للسرعة',
    meaningEn: 'The number shown (in km/h) is the maximum legal speed on this stretch of road.',
    meaningAr: 'الرقم الموضح (بالكيلومتر/ساعة) هو الحد الأقصى القانوني للسرعة في هذا الجزء من الطريق.',
  ),

  // --- Warning (yellow/red triangle, point up) ------------------------------------
  RoadSign(
    id: 'roundabout_ahead_warning',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Roundabout Ahead',
    nameAr: 'تحذير: دوار أمامك',
    meaningEn: 'A roundabout lies ahead — reduce speed and be prepared to give way to traffic already on it.',
    meaningAr: 'يوجد دوار أمامك - قلل السرعة واستعد لإعطاء الأولوية للمركبات الموجودة داخل الدوار.',
  ),
  RoadSign(
    id: 'pedestrian_crossing_warning',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Pedestrian Crossing Ahead',
    nameAr: 'تحذير: ممر مشاة أمامك',
    meaningEn: 'A pedestrian crossing is ahead; slow down and be ready to stop for pedestrians.',
    meaningAr: 'يوجد ممر مشاة أمامك؛ قلل السرعة واستعد للتوقف للمشاة.',
  ),
  RoadSign(
    id: 'school_zone',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'School Zone / Children Crossing',
    nameAr: 'منطقة مدرسة / عبور أطفال',
    meaningEn: 'A school is nearby; drive slowly and watch for children crossing or playing near the road.',
    meaningAr: 'توجد مدرسة قريبة؛ قُد بحذر وانتبه لعبور الأطفال أو لعبهم بالقرب من الطريق.',
  ),
  RoadSign(
    id: 'sharp_curve',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Sharp Curve Ahead',
    nameAr: 'منعطف حاد أمامك',
    meaningEn: 'The road curves sharply ahead in the direction shown; reduce speed before entering the bend.',
    meaningAr: 'يوجد منعطف حاد أمامك بالاتجاه الموضح؛ قلل السرعة قبل الدخول في المنعطف.',
  ),
  RoadSign(
    id: 'traffic_signals_ahead',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Traffic Signals Ahead',
    nameAr: 'إشارات مرورية أمامك',
    meaningEn: 'Signal-controlled traffic lights are ahead; be ready to slow down and stop.',
    meaningAr: 'توجد إشارات ضوئية أمامك؛ استعد لتقليل السرعة والتوقف عند الحاجة.',
  ),
  RoadSign(
    id: 'road_works',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Road Works Ahead',
    nameAr: 'أعمال طريق أمامك',
    meaningEn: 'Construction or maintenance work is ahead; slow down and follow any temporary lane markings.',
    meaningAr: 'توجد أعمال إنشاء أو صيانة أمامك؛ قلل السرعة واتبع علامات المسار المؤقتة.',
  ),
  RoadSign(
    id: 'slippery_road',
    category: 'warning',
    shape: RoadSignShape.triangle,
    primaryColor: 'yellow',
    nameEn: 'Slippery Road',
    nameAr: 'طريق زلق',
    meaningEn: 'The road surface may be slippery, especially after rain or sand; reduce speed and increase following distance.',
    meaningAr: 'قد يكون سطح الطريق زلقاً، خاصة بعد المطر أو الرمال؛ قلل السرعة وزد مسافة الأمان.',
  ),

  // --- Informatory (blue/green rectangle) -----------------------------------------
  RoadSign(
    id: 'hospital',
    category: 'informatory',
    shape: RoadSignShape.rectangle,
    primaryColor: 'blue',
    nameEn: 'Hospital',
    nameAr: 'مستشفى',
    meaningEn: 'Indicates the direction of, or proximity to, a hospital. Drive quietly and give way to ambulances.',
    meaningAr: 'تشير إلى اتجاه أو قرب مستشفى. قُد بهدوء وأعطِ الأولوية لسيارات الإسعاف.',
  ),
  RoadSign(
    id: 'parking_info',
    category: 'informatory',
    shape: RoadSignShape.rectangle,
    primaryColor: 'blue',
    nameEn: 'Parking Available',
    nameAr: 'موقف سيارات متاح',
    meaningEn: 'Marks a designated parking area nearby.',
    meaningAr: 'تشير إلى وجود منطقة وقوف سيارات مخصصة بالقرب من هذا المكان.',
  ),
  RoadSign(
    id: 'highway_exit',
    category: 'informatory',
    shape: RoadSignShape.rectangle,
    primaryColor: 'green',
    nameEn: 'Highway Exit Number',
    nameAr: 'رقم مخرج الطريق السريع',
    meaningEn: 'Green guide signs on highways show the upcoming exit number and destination(s).',
    meaningAr: 'اللوحات الإرشادية الخضراء على الطرق السريعة تُظهر رقم المخرج القادم والوجهات.',
  ),
  RoadSign(
    id: 'fuel_station',
    category: 'informatory',
    shape: RoadSignShape.rectangle,
    primaryColor: 'blue',
    nameEn: 'Fuel Station',
    nameAr: 'محطة وقود',
    meaningEn: 'Indicates a fuel/petrol station is nearby or ahead.',
    meaningAr: 'تشير إلى وجود محطة وقود قريبة أو أمامك.',
  ),
];

const List<String> roadSignCategories = ['priority', 'mandatory', 'prohibitory', 'warning', 'informatory'];

String roadSignCategoryLabel(String c) => switch (c) {
      'priority' => 'Priority & Right of Way',
      'mandatory' => 'Mandatory Signs',
      'prohibitory' => 'Prohibitory Signs',
      'warning' => 'Warning Signs',
      'informatory' => 'Informatory Signs',
      _ => c,
    };
