import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';

import '../../theme.dart';
import '../../widgets/exercise_figure.dart';

/// Ana sayfa ve kütüphanedeki renkli egzersiz kartı.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.completed = false,
    this.disabledReason,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final bool completed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final (strong, soft) = NestaColors.forKey(exercise.colorKey);
    final disabled = disabledReason != null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: soft,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ExerciseFigure(
                    exercise: exercise,
                    animate: false,
                    color: strong,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disabledReason ?? exercise.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: NestaColors.inkSoft,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          _tag(exercise.category.label, strong),
                          _tag('~${exercise.estimatedMinutes} dk', strong),
                          if (exercise.usesCamera)
                            _tag(
                              'Kamera',
                              strong,
                              icon: Icons.videocam_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: completed
                      ? NestaColors.primary
                      : Colors.white,
                  child: Icon(
                    completed ? Icons.check_rounded : Icons.play_arrow_rounded,
                    color: completed ? Colors.white : strong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: NestaColors.ink),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
