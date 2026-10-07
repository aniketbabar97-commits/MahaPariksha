import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads.dart';
import '../core/analytics.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/progress.dart';

/// Rewarded-ad offer: watch one video, get an hour without ads. The highest-paying ad format,
/// and the heavy users who take it most are exactly the ones a banner every screen wears down.
class AdFreeCard extends StatefulWidget {
  final Progress p;
  const AdFreeCard({super.key, required this.p});

  @override
  State<AdFreeCard> createState() => AdFreeCardState();
}

class AdFreeCardState extends State<AdFreeCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!widget.p.adFreeActive) RewardedAdManager.preload();
    // Keep the minutes-left line honest while the card is on screen.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _watch() {
    HapticFeedback.selectionClick();
    final shown = RewardedAdManager.showIfReady(onReward: () {
      widget.p.grantAdFreeHour();
      Analytics.log('ad_free_hour_claimed');
      if (mounted) setState(() {});
    });
    if (!shown) {
      RewardedAdManager.preload();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('विज्ञापन लोड हो रहा है, कुछ सेकंड में फिर कोशिश करें।',
              'The ad is still loading. Try again in a few seconds.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    if (p.adFreeActive) {
      final m = p.adFreeLeft.inMinutes + 1;
      return Card(
        child: ListTile(
          leading: Icon(Icons.timer, color: BrandColors.readable(context, BrandColors.correct, min: 3)),
          title: Text(context.tr('बिना विज्ञापन मोड चालू ✅', 'Ad-free mode on ✅')),
          subtitle: Text(context.tr('$m मिनट बाकी — पढ़ाई जारी रखें', '$m minutes left — keep going')),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: Icon(Icons.play_circle_fill, color: BrandColors.readable(context, BrandColors.saffron, min: 3)),
        title: Text(context.tr('1 घंटा बिना विज्ञापन', '1 hour ad-free'), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.tr('एक छोटा वीडियो देखें, 60 मिनट बिना रुकावट पढ़ें', 'Watch one short video, study 60 minutes uninterrupted'),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
          onPressed: RewardedAdManager.unavailable ? null : _watch,
          child: Text(context.tr('देखें', 'Watch')),
        ),
      ),
    );
  }
}
