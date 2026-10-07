import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'safety_screen.dart';
import 'symptom_checklist.dart';

/// Her seanstan önce tehlike belirtisi sorgusu.
class PreCheckScreen extends StatefulWidget {
  const PreCheckScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<PreCheckScreen> createState() => _PreCheckScreenState();
}

class _PreCheckScreenState extends State<PreCheckScreen> {
  Set<String> _selected = {};

  Future<void> _continue() async {
    final state = context.read<AppState>();
    final router = GoRouter.of(context);
    final check = SymptomCheck(
      present: _selected,
      checkedAt: state.now().toUtc(),
    );
    if (check.isClear) {
      router.pushReplacement(
        '/exercise/${widget.exercise.id}/session',
        extra: check,
      );
      return;
    }
    await state.reportSymptoms(
      check,
      AlertType.symptomBeforeSession,
      exerciseName: widget.exercise.name,
    );
    router.pushReplacement(
      '/safety',
      extra: SafetyArgs(reason: SafetyReason.symptom, check: check),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BAŞLAMADAN ÖNCE')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Bugün kendinizi nasıl hissediyorsunuz?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Şu anda aşağıdakilerden herhangi birini yaşıyorsanız işaretleyin. '
          'Hiçbiri yoksa doğrudan devam edin.',
          style: TextStyle(color: NestaColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 12),
        SymptomChecklist(
          selected: _selected,
          onChanged: (s) => setState(() => _selected = s),
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          icon: Icons.local_drink_outlined,
          text:
              'Başlamadan önce su için, rahat kıyafetler giyin ve '
              'kaymayan bir zemin seçin. Sıcak ortamda egzersiz yapmayın.',
        ),
      ],
    ),
    bottomNavigationBar: BottomAction(
      child: BusyButton(
        label: _selected.isEmpty ? 'HİÇBİRİ YOK, DEVAM ET' : 'BİLDİR',
        onPressed: _continue,
      ),
    ),
  );
}
