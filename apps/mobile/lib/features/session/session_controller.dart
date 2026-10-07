import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nesta_core/nesta_core.dart';

import '../../services/heart_rate_source.dart';
import '../../services/voice_coach.dart';

enum SessionPhase { preparing, active, resting, paused, finished }

/// Bir egzersiz seansının akışını yönetir: hazırlık geri sayımı, setler,
/// dinlenme, postür kontrolü, tekrar sayımı, nabız izlemi ve sesli koçluk.
///
/// Ekrandan bağımsızdır; zaman [tick] çağrılarıyla ilerler ve [now] dışarıdan
/// verilebildiği için birim testlerinde gerçek zaman beklemeden sınanabilir.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.exercise,
    required this.patientId,
    required this.sessionId,
    required this.gestationalWeek,
    required this.speaker,
    this.heartRateSource,
    this.heartRateZone,
    this.talkTest = false,
    this.preCheck,
    this.cameraless = false,
    this.prepareSeconds = 5,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _checker = exercise.usesCamera && !cameraless
           ? exercise.createChecker()
           : null {
    _startedAt = _now();
    _phaseStartedAt = _startedAt;
    _hrMonitor = heartRateZone == null
        ? null
        : HeartRateMonitor(heartRateZone!);
  }

  final Exercise exercise;
  final String patientId;
  final String sessionId;
  final int gestationalWeek;
  final Speaker speaker;
  final HeartRateSource? heartRateSource;
  final HeartRateZone? heartRateZone;

  /// Nabız eşiği kullanılamadığında (ör. beta bloker) konuşma testi hatırlatılır.
  final bool talkTest;
  final SymptomCheck? preCheck;

  /// Kamera kullanılamadığında egzersiz süreli rehberlik olarak yürütülür.
  final bool cameraless;
  final int prepareSeconds;
  final DateTime Function() _now;
  final FormChecker? _checker;
  HeartRateMonitor? _hrMonitor;

  late final DateTime _startedAt;
  late DateTime _phaseStartedAt;
  DateTime? _lastTick;
  StreamSubscription<int>? _hrSub;

  SessionPhase phase = SessionPhase.preparing;
  SessionPhase? _phaseBeforePause;
  int setIndex = 0;
  int _setActiveMs = 0;
  int _totalActiveMs = 0;
  int _restRemainingMs = 0;
  int _repsAtSetStart = 0;
  int _guidedReps = 0;
  int _lastTalkTestMs = 0;
  int _lastSpokenCountdown = -1;

  FormFeedback? feedback;
  String? lastCue;
  HeartRateUpdate heartRate = const HeartRateUpdate(HeartRateStatus.noData);
  SessionEndReason? endReason;
  DateTime? endedAt;

  bool get usesPoseTracking => _checker != null;
  bool get isFinished => phase == SessionPhase.finished;
  bool get isPaused => phase == SessionPhase.paused;

  int get prepareRemaining {
    if (phase != SessionPhase.preparing) return 0;
    final ms =
        prepareSeconds * 1000 -
        _now().difference(_phaseStartedAt).inMilliseconds;
    return (ms / 1000).ceil().clamp(0, prepareSeconds);
  }

  int get restRemainingSeconds => (_restRemainingMs / 1000).ceil();
  int get setElapsedSeconds => _setActiveMs ~/ 1000;
  int get totalActiveSeconds => _totalActiveMs ~/ 1000;

  /// Kamerasız yürütülen tekrar tabanlı egzersizde set süresi (tekrar × 5 sn).
  int? get _timedTargetSeconds {
    if (exercise.mode == ExerciseMode.guided) return null;
    if (_checker != null && exercise.countsReps) return null;
    return exercise.targetSeconds ?? (exercise.targetReps ?? 10) * 5;
  }

  /// Set ilerlemesi (0–1).
  double get setProgress {
    if (exercise.mode == ExerciseMode.guided) {
      final total = exercise.guidedSetSeconds * 1000;
      return total == 0 ? 0 : (_setActiveMs / total).clamp(0.0, 1.0);
    }
    final timed = _timedTargetSeconds;
    if (timed != null) return (_setActiveMs / (timed * 1000)).clamp(0.0, 1.0);
    return (repsInSet / exercise.targetReps!).clamp(0.0, 1.0);
  }

  int get repsInSet => (_checker?.summary.reps ?? 0) - _repsAtSetStart;
  int get totalReps {
    if (exercise.mode != ExerciseMode.guided)
      return _checker?.summary.reps ?? 0;
    final partial = phase == SessionPhase.active && _guidedCycleMs > 0
        ? _setActiveMs ~/ _guidedCycleMs
        : 0;
    return _guidedReps + partial;
  }

  /// Rehberli egzersizde şu anki adım ve kalan saniyesi.
  (GuidedStep, int)? get currentGuidedStep {
    if (exercise.mode != ExerciseMode.guided || exercise.guidedSteps.isEmpty) {
      return null;
    }
    final cycle =
        exercise.guidedSteps.fold<int>(0, (a, s) => a + s.seconds) * 1000;
    var inCycle = _setActiveMs % cycle;
    for (final s in exercise.guidedSteps) {
      final len = s.seconds * 1000;
      if (inCycle < len) return (s, ((len - inCycle) / 1000).ceil());
      inCycle -= len;
    }
    return (exercise.guidedSteps.last, 0);
  }

  // -------------------------------------------------------------------------
  // Yaşam döngüsü
  // -------------------------------------------------------------------------

  Future<void> start() async {
    _say(
      '${exercise.name}. $prepareSeconds saniye içinde başlıyoruz. '
      '${exercise.usesCamera && !cameraless ? exercise.cameraView!.setupHint : ''}',
    );
    final source = heartRateSource;
    if (source != null && _hrMonitor != null) {
      _hrSub = source.start().listen(_onHeartRate);
    }
  }

  void _say(String text, {bool interrupt = false}) {
    lastCue = text;
    speaker.say(text, interrupt: interrupt);
  }

  void _setPhase(SessionPhase p) {
    phase = p;
    _phaseStartedAt = _now();
  }

  /// Zamanı ilerletir; ekran saniyede birkaç kez çağırır.
  void tick() {
    final now = _now();
    final dt = _lastTick == null
        ? 0
        : now.difference(_lastTick!).inMilliseconds.clamp(0, 2000);
    _lastTick = now;

    switch (phase) {
      case SessionPhase.preparing:
        final remaining = prepareRemaining;
        if (remaining <= 3 &&
            remaining > 0 &&
            remaining != _lastSpokenCountdown) {
          _lastSpokenCountdown = remaining;
          speaker.say('$remaining');
        }
        if (remaining == 0) _beginSet();
      case SessionPhase.active:
        _setActiveMs += dt;
        _totalActiveMs += dt;
        _advanceActive();
        if (talkTest && _totalActiveMs - _lastTalkTestMs >= 180000) {
          _lastTalkTestMs = _totalActiveMs;
          _say(talkTestCue);
        }
      case SessionPhase.resting:
        _restRemainingMs -= dt;
        if (_restRemainingMs <= 0) _beginSet();
      case SessionPhase.paused:
      case SessionPhase.finished:
        break;
    }
    notifyListeners();
  }

  void _beginSet() {
    _setActiveMs = 0;
    _repsAtSetStart = _checker?.summary.reps ?? 0;
    _setPhase(SessionPhase.active);
    final setText = exercise.sets > 1 ? '${setIndex + 1}. set. ' : '';
    if (exercise.mode == ExerciseMode.guided) {
      // İlk adımın komutu bir sonraki tick'te okunur.
      _lastGuidedCue = null;
      _lastGuidedCycle = -1;
      if (setText.isNotEmpty) _say(setText);
    } else if (_checker == null) {
      _say('$setText${exercise.steps.join(' ')}');
    } else {
      _say('${setText}Başlayın.');
    }
  }

  String? _lastGuidedCue;
  int _lastGuidedCycle = -1;

  int get _guidedCycleMs =>
      exercise.guidedSteps.fold<int>(0, (a, s) => a + s.seconds) * 1000;

  void _advanceActive() {
    if (exercise.mode == ExerciseMode.guided) {
      if (_setActiveMs >= exercise.guidedSetSeconds * 1000) {
        _guidedReps += exercise.guidedRepeats;
        _lastGuidedCycle = -1;
        _completeSet();
        return;
      }
      final step = currentGuidedStep;
      final cycle = _guidedCycleMs == 0 ? 0 : _setActiveMs ~/ _guidedCycleMs;
      if (step != null &&
          (step.$1.cue != _lastGuidedCue || cycle != _lastGuidedCycle)) {
        _lastGuidedCue = step.$1.cue;
        _lastGuidedCycle = cycle;
        _say(step.$1.cue);
      }
      return;
    }
    final timed = _timedTargetSeconds;
    if (timed != null) {
      if (_setActiveMs >= timed * 1000) _completeSet();
    } else if (repsInSet >= exercise.targetReps!) {
      _completeSet();
    }
  }

  void _completeSet() {
    if (setIndex + 1 >= exercise.sets) {
      _finish(SessionEndReason.completed);
      _say(
        'Tebrikler, egzersizi tamamladınız. Kısa bir süre dinlenin ve su için.',
      );
      return;
    }
    setIndex++;
    if (exercise.restSeconds <= 0) {
      _beginSet();
      return;
    }
    _restRemainingMs = exercise.restSeconds * 1000;
    _setPhase(SessionPhase.resting);
    _say('Set tamamlandı. ${exercise.restSeconds} saniye dinlenin.');
  }

  void skipRest() {
    if (phase == SessionPhase.resting) {
      _beginSet();
      notifyListeners();
    }
  }

  /// Kameradan gelen poz (kişi yoksa null).
  void onPose(Pose? pose) {
    final c = _checker;
    if (c == null || phase != SessionPhase.active) return;
    final f = c.process(pose, _now().difference(_startedAt).inMilliseconds);
    feedback = f;
    if (f.cue != null) {
      _say(f.cue!, interrupt: true);
    } else if (f.repCompleted && exercise.countsReps) {
      speaker.say('${repsInSet.clamp(0, 99)}');
    }
    notifyListeners();
  }

  void _onHeartRate(int bpm) {
    final m = _hrMonitor;
    if (m == null || isFinished) return;
    heartRate = m.addSample(bpm, _now());
    if (heartRate.cue != null) _say(heartRate.cue!, interrupt: true);
    if (heartRate.shouldStop) _finish(SessionEndReason.heartRate);
    notifyListeners();
  }

  void pause() {
    if (phase == SessionPhase.finished || phase == SessionPhase.paused) return;
    _phaseBeforePause = phase;
    _setPhase(SessionPhase.paused);
    speaker.stop();
    notifyListeners();
  }

  void resume() {
    if (phase != SessionPhase.paused) return;
    final before = _phaseBeforePause ?? SessionPhase.active;
    if (before == SessionPhase.preparing) {
      _setPhase(SessionPhase.preparing);
      _lastSpokenCountdown = -1;
    } else {
      phase = before;
    }
    _lastTick = _now();
    notifyListeners();
  }

  /// Kullanıcı seansı bitirdi.
  void stopByUser() => _finish(SessionEndReason.userStopped);

  /// Kullanıcı seans sırasında tehlike belirtisi bildirdi.
  void stopForSymptom() {
    _finish(SessionEndReason.symptom);
    _say('Egzersizi bıraktınız. Oturun ve dinlenin.', interrupt: true);
  }

  void _finish(SessionEndReason reason) {
    if (isFinished) return;
    endReason = reason;
    endedAt = _now();
    phase = SessionPhase.finished;
    _hrSub?.cancel();
    heartRateSource?.stop();
    notifyListeners();
  }

  /// Bitmiş seansın kaydı.
  ExerciseSession buildSession() {
    final summary = _checker?.summary;
    return ExerciseSession(
      id: sessionId,
      patientId: patientId,
      exerciseId: exercise.id,
      startedAt: _startedAt.toUtc(),
      endedAt: (endedAt ?? _now()).toUtc(),
      endReason: endReason ?? SessionEndReason.userStopped,
      gestationalWeek: gestationalWeek,
      reps: totalReps,
      formScore: summary?.formScore,
      violationCounts: summary?.violationCounts ?? const {},
      heartRate: _hrMonitor?.summary(),
      preCheck: preCheck,
    );
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    heartRateSource?.stop();
    speaker.stop();
    super.dispose();
  }
}
