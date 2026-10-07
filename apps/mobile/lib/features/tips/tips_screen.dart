import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';

import '../../theme.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static IconData iconFor(String key) => switch (key) {
    'nutrition' => Icons.restaurant_rounded,
    'water' => Icons.water_drop_outlined,
    'mind' => Icons.spa_outlined,
    'pelvic' => Icons.favorite_border_rounded,
    'activity' => Icons.directions_walk_rounded,
    'warning' => Icons.warning_amber_rounded,
    'sleep' => Icons.bedtime_outlined,
    _ => Icons.lightbulb_outline_rounded,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İPUÇLARI')),
    body: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: tips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = tips[i];
        final warning = t.icon == 'warning';
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: warning
                    ? NestaColors.dangerSoft
                    : NestaColors.mintSoft,
                child: Icon(
                  iconFor(t.icon),
                  color: warning ? NestaColors.danger : NestaColors.primary,
                ),
              ),
              title: Text(
                t.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(t.summary),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final b in t.body)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7, right: 8),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: NestaColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(b, style: const TextStyle(height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
