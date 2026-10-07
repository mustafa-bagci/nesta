import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'exercise_card.dart';

/// Tüm egzersizler; trimestere uymayan veya ebenin kapattığı egzersizler
/// nedeniyle birlikte gösterilir.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.trimester;
    final disabled = state.disabledExercises;
    final done = state.completedToday();
    return Scaffold(
      appBar: AppBar(title: const Text('EGZERSİZLER')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final c in ExerciseCategory.values) ...[
            if (exerciseLibrary.any((e) => e.category == c))
              SectionTitle(c.label),
            for (final e in exerciseLibrary.where((e) => e.category == c))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExerciseCard(
                  exercise: e,
                  completed: done.contains(e.id),
                  disabledReason: disabled.contains(e.id)
                      ? 'Ebeniz bu egzersizi sizin için kapattı.'
                      : !e.allowedIn(t)
                      ? '${t.label} için önerilmez.'
                      : null,
                  onTap: () => context.push('/exercise/${e.id}'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
