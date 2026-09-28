import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';

const _branchColors = [
  BrandColors.saffron,
  BrandColors.skyLight,
  BrandColors.correct,
  Color(0xFF8E5CD9),
  Color(0xFFE0457B),
  Color(0xFF14A3A3),
];

/// Topic hub: one-page notes, key facts, interactive mind map, practice.
class TopicScreen extends StatelessWidget {
  final Subject subject;
  final Topic topic;
  const TopicScreen({super.key, required this.subject, required this.topic});

  @override
  Widget build(BuildContext context) {
    final s = context.scope;
    final lang = context.lang;
    final note = s.repo.note(subject.id, topic.id);
    final count = s.repo.questions.where((q) => q.subject == subject.id && q.topic == topic.id).length;

    final practice = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.saffron),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(context.tr('इस टॉपिक का अभ्यास करें ($count)', 'Practice this topic ($count)')),
          onPressed: count == 0 ? null : () => startQuiz(context, s.builder.practice(subject: subject.id, topic: topic.id)),
        ),
      ),
    );

    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: Text(topic.name.of(lang))),
        body: EmptyState(icon: Icons.edit_note, text: context.tr('इस टॉपिक के नोट्स जल्द ही आ रहे हैं।', 'Notes for this topic are coming soon.')),
        bottomNavigationBar: practice,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(topic.name.of(lang)),
          bottom: TabBar(
            indicatorColor: BrandColors.saffron,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: context.tr('नोट्स 📄', 'Notes 📄')),
              Tab(text: context.tr('मुख्य मुद्दे 🔑', 'Key facts 🔑')),
              Tab(text: context.tr('माइंड मैप 🗺️', 'Mind map 🗺️')),
            ],
          ),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(note.summary.of(lang), style: const TextStyle(fontSize: 16.5, height: 1.7)),
              ),
            ),
          ]),
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: note.facts(lang).length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: _branchColors[i % _branchColors.length].withValues(alpha: 0.18),
                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                title: Text(note.facts(lang)[i], style: const TextStyle(height: 1.45)),
              ),
            ),
          ),
          MindMapView(root: note.map, lang: lang),
        ]),
        bottomNavigationBar: practice,
      ),
    );
  }
}

class MindMapView extends StatefulWidget {
  final MapNode root;
  final String lang;
  const MindMapView({super.key, required this.root, required this.lang});

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  final Set<int> open = {};

  @override
  Widget build(BuildContext context) {
    final root = widget.root;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(gradient: BrandColors.heroGradient, borderRadius: BorderRadius.circular(30)),
            child: Text(root.label.of(widget.lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
        Center(child: Container(width: 3, height: 18, color: BrandColors.saffron.withValues(alpha: 0.5))),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
            onPressed: () => setState(() => open.length == root.children.length
                ? open.clear()
                : open.addAll(List.generate(root.children.length, (i) => i))),
            child: Text(open.length == root.children.length
                ? context.tr('सभी बंद करें', 'Collapse all')
                : context.tr('सभी खोलें', 'Expand all')),
          ),
        ]),
        for (var i = 0; i < root.children.length; i++) _branch(i, root.children[i]),
      ],
    );
  }

  Widget _branch(int i, MapNode b) {
    final color = _branchColors[i % _branchColors.length];
    final isOpen = open.contains(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isOpen ? 0.10 : 0.06),
          border: Border(left: BorderSide(color: color, width: 5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => isOpen ? open.remove(i) : open.add(i)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Expanded(
                  child: Text(b.label.of(widget.lang),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                ),
                if (b.children.isNotEmpty)
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.expand_more, color: color),
                  ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isOpen && b.children.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final leaf in b.children) _leaf(leaf, color),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  Widget _leaf(MapNode n, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.label.of(widget.lang), style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)),
              for (final c in n.children)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text('– ${c.label.of(widget.lang)}', style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor)),
                ),
            ]),
          ),
        ]),
      );
}
