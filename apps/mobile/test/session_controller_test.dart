import 'package:flutter_test/flutter_test.dart';
import 'package:nesta/features/session/session_controller.dart';
import 'package:nesta_core/nesta_core.dart';

import 'fakes.dart';

Pose _pose(DemoFrame f) => Pose({
  for (final e in f.entries)
    e.key: Landmark(e.value.$1 * 720, e.value.$2 * 720, likelihood: 0.95),
});

DemoFrame _lerp(DemoFrame a, DemoFrame b, double t) => {
  for (final j in a.keys)
    j: (
      a[j]!.$1 + (b[j]!.$1 - a[j]!.$1) * t,
      a[j]!.$2 + (b[j]!.$2 - a[j]!.$2) * t,
    ),
};

void main() {
  late FakeClock clock;
  late FakeSpeaker speaker;

  setUp(() {
    clock = FakeClock();
    speaker = FakeSpeaker();
  });

  SessionController make(
    Exercise e, {
    FakeHeartRate? hr,
    bool cameraless = false,
    bool talkTest = false,
  }) => SessionController(
    exercise: e,
    patientId: 'p1',
    sessionId: 's1',
    gestationalWeek: 24,
    speaker: speaker,
    heartRateSource: hr,
    heartRateZone: hr == null ? null : HeartRateZone.forProfile(age: 30),
    talkTest: talkTest,
    cameraless: cameraless,
    now: clock.call,
  );

  void run(
    SessionController c,
    Duration d, {
    Duration step = const Duration(milliseconds: 250),
  }) {
    var elapsed = Duration.zero;
    while (elapsed < d && !c.isFinished) {
      clock.advance(step);
      elapsed += step;
      c.tick();
    }
  }

  test('hazırlık geri sayımı sonrası set başlar', () async {
    final c = make(diaphragmaticBreathing);
    await c.start();
    c.tick();
    expect(c.phase, SessionPhase.preparing);
    run(c, const Duration(seconds: 6));
    expect(c.phase, SessionPhase.active);
    expect(speaker.said, contains('3'));
  });

  test('rehberli egzersiz tüm tekrarları sesli komutla tamamlar', () async {
    final e = diaphragmaticBreathing; // 8 × (4 + 6) sn, 1 set
    final c = make(e);
    await c.start();
    c.tick();
    run(
      c,
      const Duration(seconds: 5) + Duration(seconds: e.guidedSetSeconds + 2),
    );
    expect(c.isFinished, isTrue);
    expect(c.endReason, SessionEndReason.completed);
    expect(c.totalReps, e.guidedRepeats);
    expect(speaker.said.where((s) => s == 'Burnunuzdan nefes alın').length, 8);
    final s = c.buildSession();
    expect(s.formScore, isNull);
    expect(s.durationSeconds, greaterThanOrEqualTo(e.guidedSetSeconds));
  });

  test('setler arasında dinlenme ve atlama', () async {
    final e = pelvicFloor; // 2 set, 30 sn dinlenme
    final c = make(e);
    await c.start();
    c.tick();
    run(
      c,
      Duration(seconds: 5 + e.guidedSetSeconds) +
          const Duration(milliseconds: 500),
    );
    expect(c.phase, SessionPhase.resting);
    expect(c.setIndex, 1);
    c.skipRest();
    expect(c.phase, SessionPhase.active);
  });

  test('kamera ile tekrar sayımı seti ve egzersizi bitirir', () async {
    final e = supportedPlieSquat; // 2 × 10 tekrar
    final c = make(e);
    await c.start();
    c.tick();
    run(c, const Duration(seconds: 6));
    expect(c.phase, SessionPhase.active);

    final a = e.demoFrames.first, b = e.demoFrames.last;
    var guard = 0;
    while (!c.isFinished && guard++ < 200) {
      // Bir tekrar ~3 sn, saniyede 10 kare (cihazdaki tipik işleme hızı).
      for (final t in [
        for (var i = 0; i <= 10; i++) i / 10,
        1.0,
        1.0,
        1.0,
        for (var i = 10; i >= 0; i--) i / 10,
        0.0,
        0.0,
        0.0,
        0.0,
      ]) {
        clock.advance(const Duration(milliseconds: 100));
        c.tick();
        c.onPose(_pose(_lerp(a, b, t)));
      }
      if (c.phase == SessionPhase.resting) c.skipRest();
    }
    expect(c.isFinished, isTrue);
    expect(c.endReason, SessionEndReason.completed);
    expect(c.totalReps, 20);
    final s = c.buildSession();
    expect(s.formScore, 100);
    expect(s.violationCounts, isEmpty);
    expect(s.reps, 20);
  });

  test('kamerasız modda süreli olarak tamamlanır', () async {
    final e = catCow; // 2 × 60 sn
    final c = make(e, cameraless: true);
    expect(c.usesPoseTracking, isFalse);
    await c.start();
    c.tick();
    run(c, const Duration(seconds: 70));
    expect(c.phase, SessionPhase.resting);
    c.skipRest();
    run(c, const Duration(seconds: 61));
    expect(c.endReason, SessionEndReason.completed);
  });

  test('duraklatılınca zaman ilerlemez', () async {
    final c = make(catCow, cameraless: true);
    await c.start();
    c.tick();
    run(c, const Duration(seconds: 10));
    final before = c.setElapsedSeconds;
    c.pause();
    run(c, const Duration(seconds: 30));
    expect(c.setElapsedSeconds, before);
    c.resume();
    run(c, const Duration(seconds: 5));
    expect(c.setElapsedSeconds, greaterThan(before));
  });

  test('kritik nabız seansı durdurur', () async {
    final hr = FakeHeartRate();
    final c = make(catCow, hr: hr, cameraless: true);
    await c.start();
    hr.controller.add(150);
    await Future<void>.delayed(Duration.zero);
    clock.advance(const Duration(seconds: 5));
    hr.controller.add(160);
    await Future<void>.delayed(Duration.zero);
    clock.advance(const Duration(seconds: 11));
    hr.controller.add(162);
    await Future<void>.delayed(Duration.zero);
    expect(c.isFinished, isTrue);
    expect(c.endReason, SessionEndReason.heartRate);
    expect(hr.stopped, isTrue);
    expect(c.buildSession().heartRate!.max, 162);
  });

  test('beta bloker kullanan gebeye konuşma testi hatırlatılır', () async {
    // Pelvik taban: 2 set × 100 sn; toplam aktif süre 180 sn'yi geçer.
    final c = make(pelvicFloor, talkTest: true);
    await c.start();
    c.tick();
    run(c, const Duration(seconds: 5 + 100 + 1));
    expect(c.phase, SessionPhase.resting);
    expect(speaker.said, isNot(contains(talkTestCue)));
    c.skipRest();
    run(c, const Duration(seconds: 85));
    expect(speaker.said, contains(talkTestCue));
  });

  test('kullanıcı ve belirti nedeniyle durdurma', () async {
    final c1 = make(catCow, cameraless: true);
    await c1.start();
    c1.stopByUser();
    expect(c1.endReason, SessionEndReason.userStopped);
    final c2 = make(catCow, cameraless: true);
    await c2.start();
    c2.stopForSymptom();
    expect(c2.endReason, SessionEndReason.symptom);
    expect(c2.buildSession().endReason, SessionEndReason.symptom);
  });
}
