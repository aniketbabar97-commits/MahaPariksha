import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';

const _monthsHi = [
  'जनवरी', 'फरवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
  'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Formats an auto-current-affairs item's ISO `YYYY-MM-DD` date bilingually,
/// e.g. "2 अक्टूबर 2026" / "Oct 2, 2026". Shared with [CaDigestScreen].
Bi formatCaDate(String iso) {
  final p = iso.split('-');
  final y = p[0];
  final m = int.parse(p[1]) - 1;
  final d = int.parse(p[2]);
  return Bi('$d ${_monthsHi[m]} $y', '${_monthsEn[m]} $d, $y');
}

/// Browse past days of auto-drafted current-affairs questions and take a short
/// (up to 10 Q) quiz for any one day -- same questions that already surface in
/// normal practice, just grouped by the day they were drafted.
class CaArchiveScreen extends StatelessWidget {
  const CaArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final byDate = s.builder.currentAffairsByDate();
    final dates = byDate.keys.toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('करेंट अफेयर्स आर्काइव 🗞️', 'Current Affairs archive 🗞️'))),
      body: dates.isEmpty
          ? EmptyState(
              icon: Icons.newspaper_outlined,
              text: context.tr('करेंट अफेयर्स क्विज़ जल्द आ रहे हैं — रोज़ नए अपडेट जुड़ेंगे।',
                  'Current-affairs quizzes are coming soon — new ones get added daily.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: dates.length + (dates.length > 6 ? 2 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                // Banners: after the 6th date (for a long archive) and at the very end.
                final adAt = dates.length > 6 ? {6, dates.length + 1} : {dates.length};
                if (adAt.contains(i)) return const AdSlot();
                final di = i - adAt.where((a) => a < i).length;
                final date = dates[di];
                final qs = byDate[date]!;
                final count = qs.length.clamp(0, 10);
                return TapScale(
                  child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      startQuiz(context, s.builder.currentAffairsQuiz(date));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: BrandColors.sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                          child: Icon(subjectIcon('newspaper'), color: BrandColors.skyOn(context)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(formatCaDate(date).of(lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(context.tr('$count प्रश्नों की क्विज़', '$count-question quiz'),
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
                  ),
                );
              },
            ),
    );
  }
}
