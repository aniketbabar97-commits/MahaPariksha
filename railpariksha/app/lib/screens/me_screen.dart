import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../data/models.dart';
import '../core/theme.dart';
import '../core/notifications.dart';
import '../core/purchases.dart';
import '../core/reminders.dart';
import '../data/progress.dart';
import '../core/transitions.dart';
import '../logic/auth_service.dart';
import '../widgets/common.dart';
import 'exam_strategy_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import '../core/format.dart';
import '../core/ads.dart';

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
        if (AuthService.available) _AccountCard(p: p),
        if (kShowPremiumPurchase) ...[
          SectionTitle(context.tr('प्रीमियम 👑', 'Premium 👑')),
          _PremiumCard(p: p, purchases: s.purchases),
        ],
        SectionTitle(context.tr('मेरी तैयारी 🎯', 'My preparation 🎯')),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.school, color: BrandColors.sky),
              title: Text(context.tr('परीक्षा', 'Exam')),
              subtitle: Text(exam?.name.of(lang) ?? '-'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                HapticFeedback.selectionClick();
                showExamSwitcher(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: BrandColors.sky),
              title: Text(context.tr('परीक्षा की तारीख', 'Exam date')),
              subtitle: Text(p.examDate == null
                  ? context.tr('सेट करें — काउंटडाउन शुरू होगा', 'Set it to start a countdown')
                  : '${p.examDate!.day}/${p.examDate!.month}/${p.examDate!.year}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                HapticFeedback.selectionClick();
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
        if (exam != null) ...[
          const SizedBox(height: 12),
          ActionCard(
            icon: Icons.route,
            color: BrandColors.sky,
            title: context.tr('परीक्षा रणनीति व पैटर्न 🛤️', 'Exam strategy & pattern 🛤️'),
            subtitle: context.tr('चयन प्रक्रिया, निगेटिव मार्किंग व समय प्रबंधन',
                'Selection stages, negative marking & time budgeting'),
            onTap: () => push(context, (_) => ExamStrategyScreen(exam: exam)),
          ),
        ],
        SectionTitle(context.tr('ऐप सेटिंग्स ⚙️', 'App settings ⚙️')),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active, color: BrandColors.sky),
              title: Text(context.tr('रोज़ का रिमाइंडर 🔔', 'Daily reminders 🔔')),
              subtitle: Text(context.tr(
                  'सुबह और शाम की सूचना, कभी-कभी ज़रूरत पड़ने पर अतिरिक्त',
                  'Morning and evening, plus the occasional extra when it genuinely matters')),
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
                  HapticFeedback.selectionClick();
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: p.reminderHour, minute: 0),
                  );
                  if (t == null) return;
                  p.update((p) => p.reminderHour = t.hour);
                  await applyReminders(p);
                },
              ),
            if (p.reminders)
              SwitchListTile(
                secondary: const Icon(Icons.local_fire_department, color: BrandColors.sky),
                title: Text(context.tr('स्ट्रीक SOS चेतावनी 🚨', 'Streak SOS alert 🚨')),
                subtitle: Text(context.tr(
                    'रात 9 बजे एक अतिरिक्त अलर्ट — सिर्फ तब, जब स्ट्रीक खतरे में हो',
                    'An extra alert at 9pm -- only when your streak is actually at risk')),
                value: p.streakRiskAlerts,
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  p.update((p) => p.streakRiskAlerts = v);
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
                HapticFeedback.selectionClick();
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
              onTap: () {
                HapticFeedback.selectionClick();
                launchUrl(Uri.parse(kPlayUrl), mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail, color: BrandColors.saffron),
              title: Text(context.tr('सुझाव / संपर्क 💬', 'Feedback / contact 💬')),
              onTap: () {
                HapticFeedback.selectionClick();
                launchUrl(Uri(scheme: 'mailto', path: kSupportEmail, query: 'subject=RailPariksha%20feedback'));
              },
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
                  'RailPariksha एक स्वतंत्र शैक्षणिक ऐप है। यह सरकारी ऐप नहीं है और भारतीय रेलवे, RRB, RPF या किसी भी सरकारी संस्था का प्रतिनिधित्व नहीं करता, न ही उनसे संबद्ध है। परीक्षा की जानकारी नीचे दिए आधिकारिक स्रोतों से ली गई है; अधिसूचना, तिथि व परिणाम वहीं जाँचें।',
                  'RailPariksha is an independent educational app. It is not a government app and does not represent, and is not affiliated with, Indian Railways, RRB, RPF or any government body. Exam information comes from the official sources below; always confirm notifications, dates and results there.')),
              const SizedBox(height: 10),
              Text(context.tr('आधिकारिक स्रोत', 'Official sources'), style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final src in officialSources)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(src.$2), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.open_in_new, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${context.tr(src.$1.hi, src.$1.en)} — ${src.$2}',
                            style: const TextStyle(decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 6),
              Text(context.tr('प्रश्न सेट संस्करण: ${s.repo.version} · ${fmtCount(s.repo.questions.length)} प्रश्न',
                  'Content version: ${s.repo.version} · ${fmtCount(s.repo.questions.length)} questions'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: BrandColors.wrong),
          onPressed: () async {
            HapticFeedback.selectionClick();
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(ctx.tr('सारी प्रगति मिटानी है?', 'Reset all progress?')),
                content: Text(ctx.tr('इसे वापस नहीं लाया जा सकता।', 'This cannot be undone.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('नहीं', 'No'))),
                  TextButton(
                    onPressed: () {
                      // Destructive and irreversible -- a stronger buzz than the
                      // selectionClick every other tap in this app uses, so the
                      // confirm itself feels like it carries real weight.
                      HapticFeedback.heavyImpact();
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('हां, मिटाएं', 'Yes, reset')),
                  ),
                ],
              ),
            );
            if (ok == true) await p.reset();
          },
          child: Text(context.tr('प्रगति रीसेट करें', 'Reset progress')),
        ),
        const AdSlot(),
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
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.tr('सहेजें', 'Save')),
          ),
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
      child: TapScale(
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
      ),
    );
  }
}

/// Google sign-in entry point -- deliberately lightweight: signing in only
/// fills the leaderboard display name/photo in one tap instead of typing it,
/// it never syncs progress/streaks to the cloud (see auth_service.dart). A
/// StreamBuilder so the card reacts immediately to sign-in/sign-out without
/// the rest of the Me screen needing to become stateful.
class _AccountCard extends StatelessWidget {
  final Progress p;
  const _AccountCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userChanges,
      builder: (context, snap) {
        final user = snap.data;
        return Card(
          margin: const EdgeInsets.only(top: 12),
          child: user == null
              ? ListTile(
                  leading: const Icon(Icons.login, color: BrandColors.sky),
                  title: Text(context.tr('Google से साइन इन करें', 'Sign in with Google')),
                  subtitle: Text(context.tr('लीडरबोर्ड नाम अपने आप भर जाएगा', 'Auto-fills your leaderboard name')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final signedIn = await AuthService.signInWithGoogle();
                    if (signedIn != null && (p.leaderboardName == null || p.leaderboardName!.isEmpty)) {
                      final name = signedIn.displayName;
                      if (name != null && name.trim().isNotEmpty) p.setLeaderboardName(name);
                    }
                  },
                )
              : ListTile(
                  leading: user.photoURL != null
                      ? CircleAvatar(backgroundImage: NetworkImage(user.photoURL!))
                      : const Icon(Icons.account_circle, color: BrandColors.sky),
                  title: Text(user.displayName ?? user.email ?? context.tr('साइन इन किया गया', 'Signed in')),
                  subtitle: Text(context.tr('Google से साइन इन', 'Signed in with Google')),
                  trailing: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      AuthService.signOut();
                    },
                    child: Text(context.tr('साइन आउट', 'Sign out')),
                  ),
                ),
        );
      },
    );
  }
}

/// One-time "remove ads / unlock full offline mode" purchase (non-consumable
/// product `remove_ads_offline` -- see purchases.dart and docs/IAP_EVAL.md
/// for the Play Console setup this depends on). Shows a plain "thanks" state
/// once purchased; otherwise a buy button plus a restore-purchases action for
/// anyone who reinstalled or switched devices.
class _PremiumCard extends StatefulWidget {
  final Progress p;
  final PurchaseManager purchases;
  const _PremiumCard({required this.p, required this.purchases});

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<_PremiumCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    if (p.removedAds) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.verified, color: BrandColors.saffron),
          title: Text(context.tr('प्रीमियम सक्रिय ✅', 'Premium active ✅')),
          subtitle: Text(context.tr(
              'कोई विज्ञापन नहीं, पूरा ऑफ़लाइन मोड -- धन्यवाद! 🙏',
              'No ads, full offline mode -- thank you! 🙏')),
        ),
      );
    }
    return FutureBuilder<void>(
      future: widget.purchases.ready,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final product = widget.purchases.product;
        return Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.block, color: BrandColors.sky),
              title: Text(context.tr('विज्ञापन हटाएं, ऑफ़लाइन मोड अनलॉक करें', 'Remove ads, unlock full offline mode'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  product != null
                      ? context.tr('एक बार का भुगतान -- ${product.price}', 'One-time payment -- ${product.price}')
                      : loading
                          ? context.tr('लोड हो रहा है...', 'Loading...')
                          : context.tr('अभी उपलब्ध नहीं', 'Not available right now'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                onPressed: (_busy || loading || product == null) ? null : () => _run(widget.purchases.buy),
                child: _busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.tr('खरीदें', 'Buy')),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.restore, color: BrandColors.sky),
              title: Text(context.tr('पहले खरीदा है? पुनर्स्थापित करें', 'Already purchased? Restore it')),
              onTap: _busy ? null : () => _run(widget.purchases.restore),
            ),
          ]),
        );
      },
    );
  }
}

/// Official government sources for the exam information in the app (also listed in
/// the Play Store description, as Google Play's Misleading Claims policy requires).
const officialSources = [
  (Bi('भारतीय रेलवे', 'Indian Railways'), 'https://indianrailways.gov.in'),
  (Bi('RRB ऑनलाइन आवेदन पोर्टल', 'RRB online application portal'), 'https://www.rrbapply.gov.in'),
  (Bi('RRB चंडीगढ़ (CEN सूचनाएँ, उत्तर कुंजी)', 'RRB Chandigarh (CEN notices, answer keys)'), 'https://www.rrbcdg.gov.in'),
  (Bi('रेलवे सुरक्षा बल (RPF)', 'Railway Protection Force (RPF)'), 'https://rpf.indianrailways.gov.in'),
];
