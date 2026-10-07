import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_figure.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = NestaColors.forKey(exercise.colorKey);
    final allowed =
        exercise.allowedIn(state.trimester) &&
        !state.disabledExercises.contains(exercise.id);
    final dose = exercise.mode == ExerciseMode.guided
        ? '${exercise.sets} set × ${exercise.guidedRepeats} tekrar'
        : exercise.targetReps != null
        ? '${exercise.sets} set × ${exercise.targetReps} tekrar'
        : '${exercise.sets} set × ${exercise.targetSeconds} sn';

    return Scaffold(
      appBar: AppBar(title: const Text('EGZERSİZ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: colors.$2,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(12),
            child: ExerciseFigure(exercise: exercise, color: colors.$1),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              exercise.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.repeat_rounded, size: 18),
                label: Text(dose),
              ),
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text('~${exercise.estimatedMinutes} dk'),
              ),
              if (exercise.usesCamera)
                const Chip(
                  avatar: Icon(Icons.videocam_outlined, size: 18),
                  label: Text('Postür analizi'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < exercise.steps.length; i++)
            StepTile(index: i + 1, text: exercise.steps[i], color: colors),
          const SizedBox(height: 8),
          const SectionTitle('Faydaları'),
          Text(exercise.benefits, style: const TextStyle(height: 1.45)),
          if (exercise.safetyNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            InfoBanner(
              title: 'Dikkat',
              icon: Icons.shield_outlined,
              color: NestaColors.warning,
              background: NestaColors.sandSoft,
              text: exercise.safetyNotes.join('\n'),
            ),
          ],
          if (exercise.usesCamera) ...[
            const SizedBox(height: 12),
            InfoBanner(
              title: 'Kamera yerleşimi',
              icon: Icons.phone_android_rounded,
              text:
                  '${exercise.cameraView!.setupHint} Telefonunuzu yaklaşık 2 '
                  'metre uzağa, yere ya da alçak bir yüzeye dik olarak koyun.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: allowed
            ? FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: NestaColors.peach,
                ),
                onPressed: () => context.push('/exercise/${exercise.id}/check'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('BAŞLA'),
              )
            : const InfoBanner(
                text: 'Bu egzersiz şu an programınızda yer almıyor.',
              ),
      ),
    );
  }
}
