// Sunum ve rapor için ekran görüntüleri üretir. Normal test çalıştırmasında
// atlanır; üretmek için:
//   flutter test test/screenshots_test.dart --dart-define=SHOTS=/çıktı/dizini
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nesta/app.dart';
import 'package:nesta/data/demo_repository.dart';
import 'package:nesta/features/session/safety_screen.dart';
import 'package:nesta/state/app_state.dart';
import 'package:nesta_core/nesta_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const outDir = String.fromEnvironment('SHOTS');

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.otf'));
  }
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

void main() {
  testWidgets('ekran görüntüleri', (tester) async {
    await initializeDateFormatting('tr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1179, 2556); // iPhone 15
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoRepository(prefs, autoApproveDelay: Duration.zero);
    final now = DateTime(2026, 10, 7, 9, 41);
    final state = AppState(repo, prefs, clock: () => now);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: NestaApp(state: state),
      ),
    );

    Future<void> pump([int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> shot(String name) async {
      await pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await pump();
    await shot('01_hosgeldiniz');
    await state.markWelcomeSeen();
    await pump();
    await shot('02_kayit');
    await repo.register('ayse@ornek.com', 'gizli123');
    await pump();
    await shot('03_aydinlatma');
    await state.acceptConsent(research: true);
    await pump();
    await shot('04_profil');
    await state.saveProfile(
      PregnancyProfile(
        fullName: 'Ayşe Yılmaz',
        birthDate: DateTime.utc(1995, 3, 10),
        lastMenstrualPeriod: DateTime.utc(2026, 4, 3),
        heightCm: 165,
        prePregnancyWeightKg: 62,
        riskFactors: {RiskFactor.gestationalDiabetes},
      ),
    );
    await pump();
    await shot('05_tarama');
    await state.saveScreening(
      ScreeningResult(
        answers: {for (final q in allScreeningQuestions) q.id: false},
        completedAt: now.toUtc(),
      ),
    );
    await pump();
    await shot('06_ebe_baglantisi');
    await state.linkMidwife('NESTA1');
    await pump(10);

    // Takip ekranı için geçmiş seanslar
    for (var d = 1; d < 24; d++) {
      if (d % 3 == 2) continue;
      final day = now.subtract(Duration(days: d));
      final program = dailyProgram(day, Trimester.second);
      var t = DateTime(day.year, day.month, day.day, 10);
      for (final e in program.take(3)) {
        await repo.saveSession(
          ExerciseSession(
            id: 'g$d${e.id}',
            patientId: state.uid!,
            exerciseId: e.id,
            startedAt: t.toUtc(),
            endedAt: t.add(Duration(minutes: e.estimatedMinutes)).toUtc(),
            endReason: SessionEndReason.completed,
            gestationalWeek: 26,
            reps: e.countsReps ? e.targetReps! * e.sets : 0,
            formScore: e.usesCamera ? 74 + d % 20 : null,
            heartRate: const HeartRateSummary(
              min: 92,
              avg: 124,
              max: 138,
              sampleCount: 40,
              secondsAboveZone: 0,
            ),
            rpe: 13,
          ),
        );
        t = t.add(Duration(minutes: e.estimatedMinutes + 1));
      }
    }
    await pump();
    await shot('07_ana_sayfa');

    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/tracking');
    await shot('08_takip');
    router.go('/exercises');
    await shot('09_egzersizler');
    router.go('/tips');
    await shot('10_ipuclari');
    router.go('/profile');
    await shot('11_profil');
    router.go('/home');
    await pump();
    router.push('/exercise/${supportedPlieSquat.id}');
    await shot('12_egzersiz_detay');
    router.push('/exercise/${supportedPlieSquat.id}/check');
    await shot('13_seans_oncesi');
    router.go('/home');
    await pump();
    router.push(
      '/exercise/${diaphragmaticBreathing.id}/session',
      extra: SymptomCheck(present: const {}, checkedAt: now.toUtc()),
    );
    await pump(70);
    await shot('14_seans_rehberli');
    router.go('/home');
    await pump();
    router.push(
      '/session/summary',
      extra: ExerciseSession(
        id: 'x',
        patientId: state.uid!,
        exerciseId: supportedPlieSquat.id,
        startedAt: now.toUtc().subtract(const Duration(minutes: 4)),
        endedAt: now.toUtc(),
        endReason: SessionEndReason.completed,
        gestationalWeek: 26,
        reps: 20,
        formScore: 86,
        violationCounts: const {'govde_dik': 2, 'dizler_ice': 1},
        heartRate: const HeartRateSummary(
          min: 96,
          avg: 127,
          max: 139,
          sampleCount: 48,
          secondsAboveZone: 0,
        ),
      ),
    );
    await shot('15_seans_ozeti');
    router.go(
      '/safety',
      extra: SafetyArgs(reason: SafetyReason.heartRate, bpm: 158),
    );
    await shot('16_guvenlik');
    router.go('/home');
    await pump(20);
  }, skip: outDir.isEmpty);
}
