import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nesta/app.dart';
import 'package:nesta/data/demo_repository.dart';
import 'package:nesta/state/app_state.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  testWidgets('küçük ekranda tüm sekmeler ve ekranlar taşmadan çizilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920); // 360 × 640 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoRepository(prefs, autoApproveDelay: Duration.zero);
    final now = DateTime(2026, 10, 7, 9);
    final state = AppState(repo, prefs, clock: () => now);
    await state.markWelcomeSeen();
    await repo.register('kucuk@ornek.com', 'gizli123');
    await tester.pumpWidget(NestaApp(state: state));
    await tester.pump(const Duration(milliseconds: 100));
    await state.acceptConsent(research: false);
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Gülşah Karadeniz Özdemiroğlu',
        birthDate: DateTime.utc(1988, 5, 5),
        lastMenstrualPeriod: DateTime.utc(2026, 2, 20),
        heightCm: 160,
        prePregnancyWeightKg: 82,
        riskFactors: {
          RiskFactor.gestationalDiabetes,
          RiskFactor.obesity,
          RiskFactor.advancedMaternalAge,
        },
      ),
    );
    await state.saveScreening(
      ScreeningResult(
        answers: {for (final q in allScreeningQuestions) q.id: false},
        completedAt: now.toUtc(),
      ),
    );
    await state.linkMidwife('NESTA1');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var d = 0; d < 20; d++) {
      final start = now.subtract(Duration(days: d, hours: 1));
      await repo.saveSession(
        ExerciseSession(
          id: 's$d',
          patientId: state.uid!,
          exerciseId: exerciseLibrary[d % exerciseLibrary.length].id,
          startedAt: start.toUtc(),
          endedAt: start.add(const Duration(minutes: 7)).toUtc(),
          endReason: d == 3
              ? SessionEndReason.heartRate
              : SessionEndReason.completed,
          gestationalWeek: 32,
          reps: 18,
          formScore: 70 + d,
          violationCounts: {'govde_dik': 2},
          heartRate: const HeartRateSummary(
            min: 90,
            avg: 118,
            max: 139,
            sampleCount: 30,
            secondsAboveZone: 0,
          ),
          rpe: 13,
        ),
      );
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> scrollThrough() async {
      final scrollables = find.byType(Scrollable).hitTestable();
      if (scrollables.evaluate().isEmpty) return;
      for (var i = 0; i < 8; i++) {
        await tester.drag(scrollables.first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(state.patient!.clearance.isApproved, isTrue);
    await scrollThrough();
    for (final tab in ['Takip', 'Egzersiz', 'İpuçları', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 300));
      await scrollThrough();
    }

    // Her egzersizin ayrıntı ekranı
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    for (final e in exerciseLibrary) {
      router.push('/exercise/${e.id}');
      await tester.pump(const Duration(milliseconds: 400));
      await scrollThrough();
      router.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Profil düzenleme ve tarama ekranları
    for (final path in ['/profile/edit', '/screening/edit', '/consent/view']) {
      router.push(path);
      await tester.pump(const Duration(milliseconds: 400));
      await scrollThrough();
      router.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Seans özeti
    router.push('/session/summary', extra: state.sessions.first);
    await tester.pump(const Duration(milliseconds: 400));
    await scrollThrough();
  });
}
