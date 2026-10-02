import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../core/notifications.dart';
import '../core/reminders.dart';
import '../data/progress.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

const kPlayUrl = 'https://play.google.com/store/apps/details?id=app.railpariksha';

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
        Text(context.tr('मैं 🙋', 'Me 🙋'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        if (exam != null) _IdCard(p: p, examName: exam.name.of(lang)),
        SectionTitle(context.tr('मेरी तैयारी 🎯', 'My preparation 🎯')),
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
              title: Text(context.tr('परीक्षा की तारीख', 'Exam date')),
              subtitle: Text(p.examDate == null
                  ? context.tr('सेट करें — काउंटडाउन शुरू होगा', 'Set it to start a countdown')
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
              title: Text(context.tr('रोज़ का लक्ष्य', 'Daily goal')),
              trailing: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 10, label: Text('10')),
                  ButtonSegment(value: 20, label: Text('20')),
                  ButtonSegment(value: 50, label: Text('50')),
                ],
                selected: {p.dailyGoal},
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  p.update((p) => p.dailyGoal = v.first);
                },
              ),
            ),
          ]),
        ),
        SectionTitle(context.tr('ऐप सेटिंग्स ⚙️', 'App settings ⚙️')),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active, color: BrandColors.sky),
              title: Text(context.tr('रोज़ का रिमाइंडर 🔔', 'Daily reminders 🔔')),
              subtitle: Text(context.tr('दिन में अधिकतम 2 सूचनाएं', 'At most 2 notifications a day')),
              value: p.reminders,
              onChanged: (v) async {
                HapticFeedback.selectionClick();
                // Only actually turn reminders on if the OS permission is granted --
                // otherwise the switch would show "on" while nothing ever fires.
                final granted = v ? await RailParikshaNotifications.requestPermission() : true;
                p.update((p) => p.reminders = v && granted);
                await applyReminders(p);
                if (v && !granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.tr('सूचना अनुमति नहीं मिली। सेटिंग्स में इसे चालू करें।',
                          'Notification permission denied. Enable it in system settings.'))));
                }
              },
            ),
            if (p.reminders)
              ListTile(
                leading: const Icon(Icons.schedule, color: BrandColors.sky),
                title: Text(context.tr('सुबह का समय', 'Morning time')),
                subtitle: Text('${p.reminderHour.toString().padLeft(2, '0')}:00'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: p.reminderHour, minute: 0),
                  );
                  if (t == null) return;
                  p.update((p) => p.reminderHour = t.hour);
                  await applyReminders(p);
                },
              ),
            ListTile(
              leading: const Icon(Icons.translate, color: BrandColors.sky),
              title: Text(context.tr('भाषा', 'Language')),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'hi', label: Text('हिंदी')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {p.lang},
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  p.update((p) => p.lang = v.first);
                },
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
                  DropdownMenuItem(value: 'light', child: Text(context.tr('लाइट', 'Light'))),
                  DropdownMenuItem(value: 'dark', child: Text(context.tr('डार्क', 'Dark'))),
                ],
                // The two rows above (daily goal, language) already fire
                // haptics from their SegmentedButton -- this one didn't,
                // despite being the same "pick one of a few options" pattern.
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  p.update((p) => p.theme = v ?? 'system');
                },
              ),
            ),
          ]),
        ),
        SectionTitle(context.tr('RailPariksha परिवार 🫂', 'RailPariksha family 🫂')),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.share, color: BrandColors.saffron),
              title: Text(context.tr('दोस्तों को बताएं 📣', 'Invite friends 📣')),
              subtitle: Text(context.tr('साथ पढ़ें, साथ आगे बढ़ें! (+25 XP रोज़ पहली बार)', 'Study together, soar together! (+25 XP first time daily)')),
              onTap: () async {
                await SharePlus.instance.share(ShareParams(
                    text: context.tr(
                        'मैं RailPariksha ऐप पर रोज़ अभ्यास करता हूं — RRB NTPC, ग्रुप डी, RPF समेत सभी रेलवे परीक्षाओं के लिए मुफ़्त! आप भी जुड़ें: $kPlayUrl',
                        'I practise daily on RailPariksha — free for RRB NTPC, Group D, RPF & more! Join me: $kPlayUrl')));
                if (p.claimShareReward() && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.tr('दोस्तों को बताने के लिए +25 XP! 🎉', '+25 XP for spreading the word! 🎉'))));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_rate, color: BrandColors.saffron),
              title: Text(context.tr('ऐप को रेटिंग दें ⭐', 'Rate the app ⭐')),
              onTap: () => launchUrl(Uri.parse(kPlayUrl), mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.mail, color: BrandColors.saffron),
              title: Text(context.tr('सुझाव / संपर्क 💬', 'Feedback / contact 💬')),
              onTap: () => launchUrl(Uri(scheme: 'mailto', path: kSupportEmail, query: 'subject=RailPariksha%20feedback')),
            ),
          ]),
        ),
        SectionTitle(context.tr('जानकारी ℹ️', 'About ℹ️')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('RailPariksha — सफलता की पटरी पर', 'RailPariksha — Train to succeed'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(context.tr(
                  'RailPariksha एक स्वतंत्र शैक्षणिक ऐप है। इसका भारतीय रेलवे, RRB, RPF या किसी भी भर्ती बोर्ड से कोई संबंध नहीं है। आधिकारिक जानकारी के लिए संबंधित वेबसाइट देखें।',
                  'RailPariksha is an independent educational app. It is not affiliated with Indian Railways, RRB, RPF or any recruitment board. Refer to official websites for official information.')),
              const SizedBox(height: 6),
              Text(context.tr('प्रश्न सेट संस्करण: ${s.repo.version} · ${s.repo.questions.length} प्रश्न',
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
                title: Text(ctx.tr('सारी प्रगति मिटानी है?', 'Reset all progress?')),
                content: Text(ctx.tr('इसे वापस नहीं लाया जा सकता।', 'This cannot be undone.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('नहीं', 'No'))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('हां, मिटाएं', 'Yes, reset'))),
                ],
              ),
            );
            if (ok == true) await p.reset();
          },
          child: Text(context.tr('प्रगति रीसेट करें', 'Reset progress')),
        ),
      ],
    );
  }
}

/// A railway-style aspirant ID card: name + the exact post they're training for,
/// styled like an official ID badge. Motivational framing -- "you're already on
/// your way to becoming X" -- rather than just another stats widget. Tapping the
/// name when empty prompts for one; tapping it again lets them change it.
class _IdCard extends StatelessWidget {
  final Progress p;
  final String examName;
  const _IdCard({required this.p, required this.examName});

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: p.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('अपना नाम लिखें', 'Enter your name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: ctx.tr('जैसे रोहित शर्मा', 'e.g. Rohit Sharma')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('रद्द करें', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(ctx.tr('सहेजें', 'Save'))),
        ],
      ),
    );
    if (result != null) {
      p.update((p) => p.name = result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = p.name.isEmpty ? context.tr('अभ्यर्थी', 'Aspirant') : p.name;
    // Stable per-device "ID number" -- not a real identifier, just a badge
    // detail that stays the same across app restarts instead of re-randomizing.
    final idNumber = 100000 + (p.examId.hashCode.abs() % 900000);
    return Semantics(
      button: true,
      label: context.tr('अपना नाम बदलें', 'Edit your name'),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // The only prominent, hero-sized tap target on this screen with no
          // tactile feedback at all -- every other row/button on Me now has it.
          HapticFeedback.selectionClick();
          _editName(context);
        },
        child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.badge, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('भारतीय रेलवे अभ्यर्थी', 'Indian Railways Aspirant'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(examName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('ID #$idNumber', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
          const Icon(Icons.edit, color: Colors.white54, size: 18),
        ]),
        ),
      ),
    );
  }
}
