/// Bulutta saklanan kayıtlar: gebe, ebe, onay, seans ve uyarılar.
library;

import '../util/codec.dart';
import 'pregnancy.dart';
import 'screening.dart';

enum UserRole {
  pregnant('pregnant'),
  midwife('midwife');

  const UserRole(this.id);
  final String id;

  static UserRole? byId(Object? id) {
    for (final r in UserRole.values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// KVKK aydınlatma metni ve açık rıza onayı.
class ConsentRecord {
  const ConsentRecord({
    required this.version,
    required this.acceptedAt,
    required this.healthDataProcessing,
    required this.researchParticipation,
  });

  /// Onaylanan metnin sürümü; metin değişince yeniden onay istenir.
  final String version;
  final DateTime acceptedAt;

  /// Sağlık verilerinin işlenmesine açık rıza (uygulamanın çalışması için zorunlu).
  final bool healthDataProcessing;

  /// Anonim verilerin bilimsel araştırmada kullanılmasına açık rıza (isteğe bağlı).
  final bool researchParticipation;

  Map<String, Object?> toMap() => {
        'version': version,
        'acceptedAt': millis(acceptedAt),
        'healthDataProcessing': healthDataProcessing,
        'researchParticipation': researchParticipation,
      };

  factory ConsentRecord.fromMap(Map<String, Object?> m) => ConsentRecord(
        version: m['version'] as String,
        acceptedAt: dateFrom(m['acceptedAt'])!,
        healthDataProcessing: m['healthDataProcessing'] == true,
        researchParticipation: m['researchParticipation'] == true,
      );
}

enum ClearanceStatus {
  /// Gebe henüz bir ebeye bağlanmadı.
  notRequested('not_requested', 'Ebe bağlantısı bekleniyor'),
  pending('pending', 'Ebe onayı bekleniyor'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Egzersiz önerilmedi');

  const ClearanceStatus(this.id, this.label);
  final String id;
  final String label;
}

/// Ebe/hekimin egzersiz programı için verdiği onay.
class Clearance {
  const Clearance({
    required this.status,
    this.decidedAt,
    this.decidedBy,
    this.note,
    this.disabledExercises = const {},
  });

  static const none = Clearance(status: ClearanceStatus.notRequested);

  final ClearanceStatus status;
  final DateTime? decidedAt;
  final String? decidedBy;

  /// Ebenin gebeye notu (ör. "Haftada 3 gün, 20 dakikayı geçmeyin").
  final String? note;

  /// Ebenin bu gebe için kapattığı egzersizler.
  final Set<String> disabledExercises;

  bool get isApproved => status == ClearanceStatus.approved;

  Clearance copyWith({
    ClearanceStatus? status,
    DateTime? decidedAt,
    String? decidedBy,
    String? note,
    Set<String>? disabledExercises,
  }) =>
      Clearance(
        status: status ?? this.status,
        decidedAt: decidedAt ?? this.decidedAt,
        decidedBy: decidedBy ?? this.decidedBy,
        note: note ?? this.note,
        disabledExercises: disabledExercises ?? this.disabledExercises,
      );

  Map<String, Object?> toMap() => {
        'status': status.id,
        'decidedAt': millis(decidedAt),
        'decidedBy': decidedBy,
        'note': note,
        'disabledExercises': disabledExercises.toList()..sort(),
      };

  factory Clearance.fromMap(Map<String, Object?> m) => Clearance(
        status: enumById(ClearanceStatus.values, m['status'],
            ClearanceStatus.notRequested, (s) => s.id),
        decidedAt: dateFrom(m['decidedAt']),
        decidedBy: m['decidedBy'] as String?,
        note: m['note'] as String?,
        disabledExercises: ((m['disabledExercises'] as List?) ?? const [])
            .cast<String>()
            .toSet(),
      );
}

/// Bir gebenin tüm kaydı (Firestore: `patients/{uid}`).
class PatientRecord {
  const PatientRecord({
    required this.uid,
    required this.profile,
    this.screening,
    this.consent,
    this.midwifeId,
    this.clearance = Clearance.none,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final PregnancyProfile profile;
  final ScreeningResult? screening;
  final ConsentRecord? consent;
  final String? midwifeId;
  final Clearance clearance;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Gebe egzersiz programına erişebilir mi?
  bool get canExercise =>
      screening != null &&
      screening!.outcome != ScreeningOutcome.ineligible &&
      clearance.isApproved;

  PatientRecord copyWith({
    PregnancyProfile? profile,
    ScreeningResult? screening,
    ConsentRecord? consent,
    String? midwifeId,
    Clearance? clearance,
    DateTime? updatedAt,
  }) =>
      PatientRecord(
        uid: uid,
        profile: profile ?? this.profile,
        screening: screening ?? this.screening,
        consent: consent ?? this.consent,
        midwifeId: midwifeId ?? this.midwifeId,
        clearance: clearance ?? this.clearance,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'uid': uid,
        'profile': profile.toMap(),
        'screening': screening?.toMap(),
        'consent': consent?.toMap(),
        'midwifeId': midwifeId,
        'clearance': clearance.toMap(),
        'createdAt': millis(createdAt),
        'updatedAt': millis(updatedAt),
      };

  factory PatientRecord.fromMap(Map<String, Object?> m) => PatientRecord(
        uid: m['uid'] as String,
        profile: PregnancyProfile.fromMap(mapFrom(m['profile'])),
        screening: m['screening'] == null
            ? null
            : ScreeningResult.fromMap(mapFrom(m['screening'])),
        consent: m['consent'] == null
            ? null
            : ConsentRecord.fromMap(mapFrom(m['consent'])),
        midwifeId: m['midwifeId'] as String?,
        clearance: m['clearance'] == null
            ? Clearance.none
            : Clearance.fromMap(mapFrom(m['clearance'])),
        createdAt: dateFrom(m['createdAt'])!,
        updatedAt: dateFrom(m['updatedAt'])!,
      );
}

/// Ebe/hekim kaydı (Firestore: `midwives/{uid}`).
class MidwifeRecord {
  const MidwifeRecord({
    required this.uid,
    required this.fullName,
    required this.title,
    required this.institution,
    required this.inviteCode,
  });

  final String uid;
  final String fullName;

  /// Unvan: Ebe, Uzm. Ebe, Op. Dr. vb.
  final String title;
  final String institution;

  /// Gebelerin bu ebeye bağlanmak için girdiği kod.
  final String inviteCode;

  String get displayName => '$title $fullName';

  Map<String, Object?> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'title': title,
        'institution': institution,
        'inviteCode': inviteCode,
      };

  factory MidwifeRecord.fromMap(Map<String, Object?> m) => MidwifeRecord(
        uid: m['uid'] as String,
        fullName: m['fullName'] as String,
        title: m['title'] as String,
        institution: m['institution'] as String,
        inviteCode: m['inviteCode'] as String,
      );
}

enum SessionEndReason {
  completed('completed', 'Tamamlandı'),
  userStopped('user_stopped', 'Kullanıcı bitirdi'),
  symptom('symptom', 'Tehlike belirtisi'),
  heartRate('heart_rate', 'Nabız sınırı aşıldı');

  const SessionEndReason(this.id, this.label);
  final String id;
  final String label;
}

/// Seans süresince nabız özeti.
class HeartRateSummary {
  const HeartRateSummary({
    required this.min,
    required this.avg,
    required this.max,
    required this.sampleCount,
    required this.secondsAboveZone,
    this.zoneLow,
    this.zoneHigh,
  });

  final int min;
  final int avg;
  final int max;
  final int sampleCount;
  final int secondsAboveZone;
  final int? zoneLow;
  final int? zoneHigh;

  Map<String, Object?> toMap() => {
        'min': min,
        'avg': avg,
        'max': max,
        'sampleCount': sampleCount,
        'secondsAboveZone': secondsAboveZone,
        'zoneLow': zoneLow,
        'zoneHigh': zoneHigh,
      };

  factory HeartRateSummary.fromMap(Map<String, Object?> m) => HeartRateSummary(
        min: (m['min'] as num).toInt(),
        avg: (m['avg'] as num).toInt(),
        max: (m['max'] as num).toInt(),
        sampleCount: (m['sampleCount'] as num).toInt(),
        secondsAboveZone: (m['secondsAboveZone'] as num?)?.toInt() ?? 0,
        zoneLow: (m['zoneLow'] as num?)?.toInt(),
        zoneHigh: (m['zoneHigh'] as num?)?.toInt(),
      );
}

/// Tamamlanan (veya yarıda kalan) bir egzersiz seansı
/// (Firestore: `patients/{uid}/sessions/{id}`).
class ExerciseSession {
  const ExerciseSession({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.startedAt,
    required this.endedAt,
    required this.endReason,
    required this.gestationalWeek,
    this.reps = 0,
    this.formScore,
    this.violationCounts = const {},
    this.heartRate,
    this.rpe,
    this.preCheck,
    this.postCheck,
    this.note,
  });

  final String id;
  final String patientId;
  final String exerciseId;
  final DateTime startedAt;
  final DateTime endedAt;
  final SessionEndReason endReason;
  final int gestationalWeek;
  final int reps;

  /// Doğru postürde geçen sürenin yüzdesi (kamerasız egzersizlerde null).
  final int? formScore;

  /// Kural kimliği → kaç kez uyarı verildi.
  final Map<String, int> violationCounts;
  final HeartRateSummary? heartRate;

  /// Borg algılanan zorlanma (6–20).
  final int? rpe;
  final SymptomCheck? preCheck;
  final SymptomCheck? postCheck;
  final String? note;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;
  int get totalWarnings => violationCounts.values.fold(0, (a, b) => a + b);

  ExerciseSession copyWith({
    int? rpe,
    SymptomCheck? postCheck,
    String? note,
  }) =>
      ExerciseSession(
        id: id,
        patientId: patientId,
        exerciseId: exerciseId,
        startedAt: startedAt,
        endedAt: endedAt,
        endReason: endReason,
        gestationalWeek: gestationalWeek,
        reps: reps,
        formScore: formScore,
        violationCounts: violationCounts,
        heartRate: heartRate,
        rpe: rpe ?? this.rpe,
        preCheck: preCheck,
        postCheck: postCheck ?? this.postCheck,
        note: note ?? this.note,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'patientId': patientId,
        'exerciseId': exerciseId,
        'startedAt': millis(startedAt),
        'endedAt': millis(endedAt),
        'endReason': endReason.id,
        'gestationalWeek': gestationalWeek,
        'reps': reps,
        'formScore': formScore,
        'violationCounts': violationCounts,
        'heartRate': heartRate?.toMap(),
        'rpe': rpe,
        'preCheck': preCheck?.toMap(),
        'postCheck': postCheck?.toMap(),
        'note': note,
      };

  factory ExerciseSession.fromMap(Map<String, Object?> m) => ExerciseSession(
        id: m['id'] as String,
        patientId: m['patientId'] as String,
        exerciseId: m['exerciseId'] as String,
        startedAt: dateFrom(m['startedAt'])!,
        endedAt: dateFrom(m['endedAt'])!,
        endReason: enumById(SessionEndReason.values, m['endReason'],
            SessionEndReason.completed, (r) => r.id),
        gestationalWeek: (m['gestationalWeek'] as num?)?.toInt() ?? 0,
        reps: (m['reps'] as num?)?.toInt() ?? 0,
        formScore: (m['formScore'] as num?)?.toInt(),
        violationCounts: mapFrom(m['violationCounts'])
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        heartRate: m['heartRate'] == null
            ? null
            : HeartRateSummary.fromMap(mapFrom(m['heartRate'])),
        rpe: (m['rpe'] as num?)?.toInt(),
        preCheck: m['preCheck'] == null
            ? null
            : SymptomCheck.fromMap(mapFrom(m['preCheck'])),
        postCheck: m['postCheck'] == null
            ? null
            : SymptomCheck.fromMap(mapFrom(m['postCheck'])),
        note: m['note'] as String?,
      );
}

enum AlertType {
  symptomBeforeSession('symptom_before', 'Seans öncesi tehlike belirtisi'),
  symptomDuringSession('symptom_during', 'Seans sırasında tehlike belirtisi'),
  symptomAfterSession('symptom_after', 'Seans sonrası tehlike belirtisi'),
  heartRateLimit('heart_rate', 'Nabız sınırı aşıldı'),
  screeningUpdated('screening_updated', 'Tarama formu güncellendi');

  const AlertType(this.id, this.label);
  final String id;
  final String label;
}

/// Ebeye iletilen uyarı (Firestore: `alerts/{id}`).
class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.midwifeId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.urgent = false,
    this.acknowledgedAt,
    this.sessionId,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String midwifeId;
  final AlertType type;
  final String message;
  final DateTime createdAt;
  final bool urgent;
  final DateTime? acknowledgedAt;
  final String? sessionId;

  bool get isAcknowledged => acknowledgedAt != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'midwifeId': midwifeId,
        'type': type.id,
        'message': message,
        'createdAt': millis(createdAt),
        'urgent': urgent,
        'acknowledgedAt': millis(acknowledgedAt),
        'sessionId': sessionId,
      };

  factory AlertRecord.fromMap(Map<String, Object?> m) => AlertRecord(
        id: m['id'] as String,
        patientId: m['patientId'] as String,
        patientName: (m['patientName'] as String?) ?? '',
        midwifeId: m['midwifeId'] as String,
        type: enumById(AlertType.values, m['type'],
            AlertType.symptomDuringSession, (t) => t.id),
        message: m['message'] as String,
        createdAt: dateFrom(m['createdAt'])!,
        urgent: m['urgent'] == true,
        acknowledgedAt: dateFrom(m['acknowledgedAt']),
        sessionId: m['sessionId'] as String?,
      );
}
