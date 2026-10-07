import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 9);

  test('PatientRecord serileştirme ve egzersiz izni', () {
    final p = PatientRecord(
      uid: 'u1',
      profile: PregnancyProfile(
          fullName: 'Test',
          birthDate: DateTime.utc(1995, 1, 1),
          dueDate: DateTime.utc(2027, 1, 1)),
      screening: ScreeningResult(
          answers: {for (final q in allScreeningQuestions) q.id: false},
          completedAt: t0),
      consent: ConsentRecord(
          version: consentVersion,
          acceptedAt: t0,
          healthDataProcessing: true,
          researchParticipation: false),
      midwifeId: 'm1',
      clearance: Clearance(
          status: ClearanceStatus.approved,
          decidedAt: t0,
          decidedBy: 'm1',
          note: 'Haftada 3 gün',
          disabledExercises: {'kus_kopek'}),
      createdAt: t0,
      updatedAt: t0,
    );
    expect(p.canExercise, isTrue);
    final back = PatientRecord.fromMap(p.toMap());
    expect(back.clearance.status, ClearanceStatus.approved);
    expect(back.clearance.disabledExercises, {'kus_kopek'});
    expect(back.consent!.version, consentVersion);
    expect(back.midwifeId, 'm1');
    expect(back.canExercise, isTrue);

    final pending = p.copyWith(
        clearance: p.clearance.copyWith(status: ClearanceStatus.pending));
    expect(pending.canExercise, isFalse);
  });

  test('ExerciseSession serileştirme', () {
    final s = ExerciseSession(
      id: 's1',
      patientId: 'u1',
      exerciseId: 'destekli_plie_squat',
      startedAt: t0,
      endedAt: t0.add(const Duration(minutes: 3, seconds: 20)),
      endReason: SessionEndReason.heartRate,
      gestationalWeek: 24,
      reps: 12,
      formScore: 87,
      violationCounts: {'govde_dik': 2, 'cok_derin': 1},
      heartRate: const HeartRateSummary(
          min: 90,
          avg: 120,
          max: 162,
          sampleCount: 40,
          secondsAboveZone: 25,
          zoneLow: 121,
          zoneHigh: 141),
      rpe: 13,
      preCheck: SymptomCheck(present: {}, checkedAt: t0),
    );
    final back = ExerciseSession.fromMap(s.toMap());
    expect(back.durationSeconds, 200);
    expect(back.totalWarnings, 3);
    expect(back.endReason, SessionEndReason.heartRate);
    expect(back.heartRate!.max, 162);
    expect(back.rpe, 13);
    expect(back.preCheck!.isClear, isTrue);
    expect(back.postCheck, isNull);
  });

  test('AlertRecord serileştirme', () {
    final a = AlertRecord(
        id: 'a1',
        patientId: 'u1',
        patientName: 'Test',
        midwifeId: 'm1',
        type: AlertType.symptomBeforeSession,
        message: 'Baş ağrısı',
        createdAt: t0,
        urgent: true);
    final back = AlertRecord.fromMap(a.toMap());
    expect(back.type, AlertType.symptomBeforeSession);
    expect(back.urgent, isTrue);
    expect(back.isAcknowledged, isFalse);
  });

  test('bilinmeyen enum değeri varsayılana düşer', () {
    final c = Clearance.fromMap({'status': 'garip'});
    expect(c.status, ClearanceStatus.notRequested);
  });
}
