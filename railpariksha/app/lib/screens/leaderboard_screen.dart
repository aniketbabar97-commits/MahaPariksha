import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../logic/leaderboard_service.dart';
import '../widgets/common.dart';

/// Anonymous, per-exam, weekly leaderboard -- see logic/leaderboard_service.dart for
/// the schema/privacy model. Entirely optional on top of the app's offline-first core:
/// shows a plain "unavailable" state rather than erroring when Firebase isn't configured.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<(List<LeaderboardEntry>, int?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<LeaderboardEntry>, int?)> _load() async {
    final p = context.scope.progress;
    final examId = p.examId;
    if (examId == null) return (const <LeaderboardEntry>[], null);
    final top = await LeaderboardService.top(examId: examId);
    final rank = p.deviceId == null ? null : await LeaderboardService.myRank(examId: examId, deviceId: p.deviceId!);
    return (top, rank);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final p = s.progress;
    final exam = s.builder.exam;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('लीडरबोर्ड 🏆', 'Leaderboard 🏆')),
        actions: [
          if (p.leaderboardName != null)
            IconButton(icon: const Icon(Icons.edit), tooltip: context.tr('नाम बदलें', 'Change name'), onPressed: () => _promptName(context)),
        ],
      ),
      body: !LeaderboardService.available
          ? EmptyState(
              icon: Icons.leaderboard,
              text: context.tr('लीडरबोर्ड अभी उपलब्ध नहीं है', 'Leaderboard isn\'t available right now'),
            )
          : exam == null
              ? EmptyState(
                  icon: Icons.school,
                  text: context.tr('पहले अपनी परीक्षा चुनें', 'Pick your exam first'),
                )
              : p.leaderboardName == null
                  ? _NamePrompt(onSet: (name) {
                      p.setLeaderboardName(name);
                      setState(() {});
                      _refresh();
                    })
                  : RefreshIndicator(
                      onRefresh: () async {
                        _refresh();
                        await _future;
                      },
                      child: FutureBuilder(
                        future: _future,
                        builder: (context, snap) {
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          final (top, rank) = snap.data!;
                          final lang = context.lang;
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              Text(exam.name.of(lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              Text(context.tr('इस सप्ताह का टॉप 20', "This week's top 20"), style: TextStyle(color: Theme.of(context).hintColor)),
                              const SizedBox(height: 4),
                              if (rank != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(14)),
                                  child: Row(children: [
                                    const Icon(Icons.military_tech, color: BrandColors.sunrise),
                                    const SizedBox(width: 10),
                                    Text(context.tr('आपकी रैंक: #$rank', 'Your rank: #$rank'),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (top.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: EmptyState(
                                    icon: Icons.emoji_events,
                                    text: context.tr('अभी कोई स्कोर नहीं — पहला मॉक टेस्ट देकर टॉप पर आएं!',
                                        'No scores yet -- take a mock test to be the first on the board!'),
                                  ),
                                )
                              else
                                for (var i = 0; i < top.length; i++)
                                  _Row(index: i, entry: top[i], isMe: top[i].deviceId == p.deviceId),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }

  void _promptName(BuildContext context) {
    HapticFeedback.selectionClick();
    final p = context.scope.progress;
    showDialog<String>(
      context: context,
      builder: (ctx) => _NameDialog(initial: p.leaderboardName ?? ''),
    ).then((name) {
      if (name == null || !mounted) return;
      p.setLeaderboardName(name);
      setState(() {});
      _refresh();
    });
  }
}

class _Row extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;
  final bool isMe;
  const _Row({required this.index, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final medal = switch (index) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => null };
    return Card(
      color: isMe ? BrandColors.saffron.withValues(alpha: 0.12) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          child: Text(medal ?? '${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        title: Text(entry.name + (isMe ? context.tr(' (आप)', ' (you)') : ''),
            style: TextStyle(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600)),
        trailing: Text('${entry.score.toStringAsFixed(entry.score == entry.score.roundToDouble() ? 0 : 2)} / ${entry.total}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _NamePrompt extends StatelessWidget {
  final ValueChanged<String> onSet;
  const _NamePrompt({required this.onSet});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.leaderboard, color: BrandColors.sky, size: 48),
          const SizedBox(height: 12),
          Text(context.tr('लीडरबोर्ड में शामिल हों', 'Join the leaderboard'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          Text(
              context.tr('कोई लॉगिन नहीं — सिर्फ एक नाम चुनें, आपकी पहचान गुप्त रहेगी',
                  'No login needed -- just pick a name, your real identity stays private'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.edit),
            label: Text(context.tr('नाम चुनें', 'Pick a name')),
            onPressed: () {
              HapticFeedback.selectionClick();
              showDialog<String>(context: context, builder: (ctx) => const _NameDialog(initial: '')).then((name) {
                if (name != null) onSet(name);
              });
            },
          ),
        ]),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('अपना लीडरबोर्ड नाम चुनें', 'Pick your leaderboard name')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        decoration: InputDecoration(hintText: context.tr('जैसे: RailWarrior99', 'e.g. RailWarrior99')),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('रद्द करें', 'Cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.tr('सेव करें', 'Save')),
        ),
      ],
    );
  }
}
