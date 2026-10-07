import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

DemoFrame _with(DemoFrame f, Map<Joint, (double, double)> overrides) =>
    {...f, ...overrides};

FormSummary _run(Exercise e,
    {int cycles = 3, DemoFrame Function(DemoFrame)? transform}) {
  final checker = e.createChecker();
  for (final (pose, t)
      in playDemo(e.demoFrames, cycles: cycles, transform: transform)) {
    checker.process(pose, t);
  }
  return checker.summary;
}

void main() {
  test('egzersiz kimlikleri benzersiz ve kütüphaneden bulunabilir', () {
    final ids = exerciseLibrary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(exerciseById(id)!.id, id);
    }
  });

  test('her egzersizin içeriği eksiksiz', () {
    for (final e in exerciseLibrary) {
      expect(e.steps, isNotEmpty, reason: e.id);
      expect(e.trimesters, isNotEmpty, reason: e.id);
      expect(e.estimatedMinutes, greaterThan(0), reason: e.id);
      if (e.usesCamera) {
        expect(e.cameraView, isNotNull, reason: e.id);
        expect(e.rules, isNotEmpty, reason: e.id);
        expect(e.demoFrames.length, greaterThanOrEqualTo(2), reason: e.id);
        expect(e.targetReps != null || e.targetSeconds != null, isTrue,
            reason: e.id);
      } else {
        expect(e.guidedSteps, isNotEmpty, reason: e.id);
      }
    }
  });

  test('kural kimlikleri egzersiz içinde benzersiz', () {
    for (final e in exerciseLibrary.where((e) => e.usesCamera)) {
      final ids = e.rules.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length, reason: e.id);
    }
  });

  group('demo animasyonu kendi kurallarına uyar', () {
    for (final e in exerciseLibrary.where((e) => e.usesCamera)) {
      test(e.id, () {
        final s = _run(e);
        expect(s.violationCounts, isEmpty,
            reason: '${e.id}: ${s.violationCounts}');
        expect(s.formScore, 100);
        if (e.repSpec != null) expect(s.reps, 3);
      });
    }
  });

  group('hatalı hareketler yakalanır', () {
    test('plié: çok derin çömelme', () {
      final s = _run(supportedPlieSquat, transform: (f) {
        // Kalçayı diz hizasının altına indir.
        final deep = f[Joint.leftHip]!.$2 > 0.6;
        if (!deep) return f;
        return _with(f, {
          Joint.leftHip: (0.57, 0.78),
          Joint.rightHip: (0.43, 0.78),
        });
      });
      expect(s.violationCounts['cok_derin'], greaterThan(0));
    });

    test('plié: dizlerin içe kaçması', () {
      final s = _run(supportedPlieSquat,
          transform: (f) => _with(f, {
                Joint.leftKnee: (0.55, f[Joint.leftKnee]!.$2),
                Joint.rightKnee: (0.45, f[Joint.rightKnee]!.$2),
              }));
      expect(s.violationCounts['dizler_ice'], greaterThan(0));
    });

    test('yana esneme: aşırı eğilme', () {
      final s = _run(standingSideBend, transform: (f) {
        if (f[Joint.leftShoulder]!.$2 < 0.28) return f;
        return _with(f, {
          Joint.rightShoulder: (0.62, 0.30),
          Joint.leftShoulder: (0.78, 0.42),
        });
      });
      expect(s.violationCounts['asiri_egilme'], greaterThan(0));
    });

    test('kuş-köpek: bacak kalça üstüne çıkıyor', () {
      final s = _run(birdDog, transform: (f) {
        if (f[Joint.leftAnkle]!.$2 > 0.6) return f;
        return _with(f, {Joint.leftAnkle: (0.05, 0.30)});
      });
      expect(s.violationCounts['bacak_kalca_ustu'], greaterThan(0));
    });

    test('yan yatış: bacak çok yüksek', () {
      final s = _run(sideLyingLegLift, transform: (f) {
        if (f[Joint.rightAnkle]!.$2 > 0.65) return f;
        return _with(f, {Joint.rightAnkle: (0.80, 0.38)});
      });
      expect(s.violationCounts['bacak_cok_yuksek'], greaterThan(0));
    });

    test('kedi-inek: eller omuzların önünde', () {
      final s = _run(catCow,
          transform: (f) => _with(f, {
                Joint.leftWrist: (0.88, 0.85),
                Joint.rightWrist: (0.865, 0.84),
              }));
      expect(s.violationCounts['eller_omuz_altinda'], greaterThan(0));
    });

    test('oturarak kol kaldırma: kollar asimetrik', () {
      final s = _run(seatedArmRaise,
          transform: (f) => _with(f, {
                Joint.leftWrist: (0.65, 0.56),
                Joint.leftElbow: (0.64, 0.44),
              }));
      expect(s.violationCounts['kol_simetrisi'], greaterThan(0));
    });
  });

  group('program', () {
    final day = DateTime(2026, 10, 7);

    test('günlük program ısınma ve pelvik tabanla başlar/biter', () {
      for (final t in Trimester.values) {
        final p = dailyProgram(day, t);
        expect(p.first.category, ExerciseCategory.breathing);
        expect(p.last.category, ExerciseCategory.pelvicFloor);
        expect(p.length, 5);
        expect(p.every((e) => e.allowedIn(t)), isTrue);
      }
    });

    test('kuş-köpek 3. trimesterde önerilmez', () {
      expect(availableExercises(Trimester.third).map((e) => e.id),
          isNot(contains('kus_kopek')));
      expect(availableExercises(Trimester.second).map((e) => e.id),
          contains('kus_kopek'));
    });

    test('ebenin kapattığı egzersiz programa girmez', () {
      for (var i = 0; i < 14; i++) {
        final p = dailyProgram(day.add(Duration(days: i)), Trimester.second,
            disabled: {'destekli_plie_squat', 'pelvik_taban'});
        expect(
            p.map((e) => e.id),
            isNot(anyOf(
                contains('destekli_plie_squat'), contains('pelvik_taban'))));
      }
    });

    test('program günden güne değişir', () {
      final a = dailyProgram(day, Trimester.second).map((e) => e.id).toList();
      final b = dailyProgram(day.add(const Duration(days: 1)), Trimester.second)
          .map((e) => e.id)
          .toList();
      expect(a, isNot(equals(b)));
    });
  });
}
