import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

const kPlayUrl = 'https://play.google.com/store/apps/details?id=app.bharari';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final p = s.progress;
    final lang = context.lang;
    final exam = s.builder.exam;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(context.tr('मी', 'Me'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        SectionTitle(context.tr('माझी तयारी', 'My preparation')),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.school, color: BrandColors.sky),
              title: Text(context.tr('परीक्षा', 'Exam')),
              subtitle: Text(exam?.name.of(lang) ?? '-'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showExamSwitcher(context),
            ),
            ListTile(
              leading: const Icon(Icons.event, color: BrandColors.sky),
              title: Text(context.tr('परीक्षेची तारीख', 'Exam date')),
              subtitle: Text(p.examDate == null
                  ? context.tr('सेट करा — काउंटडाउन सुरू होईल', 'Set it to start a countdown')
                  : '${p.examDate!.day}/${p.examDate!.month}/${p.examDate!.year}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: p.examDate ?? now.add(const Duration(days: 60)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 730)),
                );
                if (d != null) p.update((p) => p.examDate = d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: BrandColors.sky),
              title: Text(context.tr('रोजचे लक्ष्य', 'Daily goal')),
              trailing: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 10, label: Text('10')),
                  ButtonSegment(value: 20, label: Text('20')),
                  ButtonSegment(value: 50, label: Text('50')),
                ],
                selected: {p.dailyGoal},
                onSelectionChanged: (v) => p.update((p) => p.dailyGoal = v.first),
              ),
            ),
          ]),
        ),
        SectionTitle(context.tr('ॲप सेटिंग्ज', 'App settings')),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.translate, color: BrandColors.sky),
              title: Text(context.tr('भाषा', 'Language')),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'mr', label: Text('मराठी')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {p.lang},
                onSelectionChanged: (v) => p.update((p) => p.lang = v.first),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: BrandColors.sky),
              title: Text(context.tr('थीम', 'Theme')),
              trailing: DropdownButton<String>(
                value: p.theme,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'system', child: Text(context.tr('सिस्टम', 'System'))),
                  DropdownMenuItem(value: 'light', child: Text(context.tr('लाईट', 'Light'))),
                  DropdownMenuItem(value: 'dark', child: Text(context.tr('डार्क', 'Dark'))),
                ],
                onChanged: (v) => p.update((p) => p.theme = v ?? 'system'),
              ),
            ),
          ]),
        ),
        SectionTitle(context.tr('भरारी परिवार', 'Bharari family')),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.share, color: BrandColors.saffron),
              title: Text(context.tr('मित्रांना सांगा', 'Invite friends')),
              subtitle: Text(context.tr('एकत्र अभ्यास, एकत्र भरारी!', 'Study together, soar together!')),
              onTap: () => SharePlus.instance.share(ShareParams(
                  text: context.tr(
                      'मी भरारी ॲपवर रोज सराव करतो — पोलीस भरती, तलाठी, MPSC सर्व परीक्षांसाठी मोफत! तुम्हीही जॉईन व्हा: $kPlayUrl',
                      'I practise daily on Bharari — free for Police Bharti, Talathi, MPSC & more! Join me: $kPlayUrl'))),
            ),
            ListTile(
              leading: const Icon(Icons.star_rate, color: BrandColors.saffron),
              title: Text(context.tr('ॲपला रेटिंग द्या', 'Rate the app')),
              onTap: () => launchUrl(Uri.parse(kPlayUrl), mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.mail, color: BrandColors.saffron),
              title: Text(context.tr('सूचना / संपर्क', 'Feedback / contact')),
              onTap: () => launchUrl(Uri(scheme: 'mailto', path: kSupportEmail, query: 'subject=Bharari%20feedback')),
            ),
          ]),
        ),
        SectionTitle(context.tr('माहिती', 'About')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('भरारी — उंच भरारी घ्या', 'Bharari — Fly high'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(context.tr(
                  'भरारी हे स्वतंत्र शैक्षणिक ॲप आहे. याचा कोणत्याही शासकीय विभाग, MPSC किंवा भरती मंडळाशी संबंध नाही. अधिकृत माहितीसाठी संबंधित संकेतस्थळ पहा.',
                  'Bharari is an independent educational app. It is not affiliated with any government department, MPSC or recruitment board. Refer to official websites for official information.')),
              const SizedBox(height: 6),
              Text(context.tr('प्रश्न संच आवृत्ती: ${s.repo.version} · ${s.repo.questions.length} प्रश्न',
                  'Content version: ${s.repo.version} · ${s.repo.questions.length} questions'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: BrandColors.wrong),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(ctx.tr('सर्व प्रगती पुसायची?', 'Reset all progress?')),
                content: Text(ctx.tr('हे परत आणता येणार नाही.', 'This cannot be undone.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('नाही', 'No'))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('हो, पुसा', 'Yes, reset'))),
                ],
              ),
            );
            if (ok == true) await p.reset();
          },
          child: Text(context.tr('प्रगती रीसेट करा', 'Reset progress')),
        ),
      ],
    );
  }
}
