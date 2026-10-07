/// Egzersiz tanımı.
library;

import '../models/pregnancy.dart';
import '../pose/form_checker.dart';
import '../pose/pose.dart';

enum ExerciseCategory {
  breathing('Nefes'),
  mobility('Esneklik'),
  strength('Kuvvet'),
  balance('Denge'),
  pelvicFloor('Pelvik Taban');

  const ExerciseCategory(this.label);
  final String label;
}

/// Egzersizin nasıl takip edildiği.
enum ExerciseMode {
  /// Kamera ile postür analizi yapılır.
  camera,

  /// Kamera kullanılmaz; sesli komutlarla zamanlanmış rehberlik verilir.
  guided,
}

enum CameraView {
  side(
      'Telefonu yanınıza, vücudunuzun tamamını yandan görecek şekilde yerleştirin.'),
  front(
      'Telefonu karşınıza, vücudunuzun tamamını önden görecek şekilde yerleştirin.');

  const CameraView(this.setupHint);
  final String setupHint;
}

/// Kamerasız egzersizlerde bir sesli adım (ör. "Kasın" — 5 sn).
class GuidedStep {
  const GuidedStep(this.cue, this.seconds);
  final String cue;
  final int seconds;
}

/// Demo animasyonu için normalize (0–1, y aşağı) eklem konumları.
typedef DemoFrame = Map<Joint, (double, double)>;

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.mode,
    required this.trimesters,
    required this.steps,
    required this.benefits,
    this.safetyNotes = const [],
    this.cameraView,
    this.targetReps,
    this.targetSeconds,
    this.sets = 1,
    this.restSeconds = 30,
    this.guidedSteps = const [],
    this.guidedRepeats = 1,
    this.demoFrames = const [],
    this.colorKey = 'mint',
    this.buildRules,
    this.isBodyVisible,
    this.repSpec,
  });

  final String id;
  final String name;
  final String summary;
  final ExerciseCategory category;
  final ExerciseMode mode;
  final Set<Trimester> trimesters;

  /// Ekranda numaralı olarak gösterilen uygulama adımları.
  final List<String> steps;
  final String benefits;
  final List<String> safetyNotes;
  final CameraView? cameraView;

  /// Set başına hedef tekrar (tekrar sayılan egzersizler).
  final int? targetReps;

  /// Set başına hedef süre (süreli egzersizler).
  final int? targetSeconds;
  final int sets;
  final int restSeconds;

  final List<GuidedStep> guidedSteps;
  final int guidedRepeats;

  /// En az iki kare: başlangıç ve hareketin uç noktası.
  final List<DemoFrame> demoFrames;

  /// Arayüzde kart rengi için anahtar (mint, peach, sand, lilac, sky).
  final String colorKey;

  final List<PostureRule> Function()? buildRules;
  final bool Function(Pose pose)? isBodyVisible;
  final RepSpec? repSpec;

  bool get usesCamera => mode == ExerciseMode.camera;
  bool get countsReps => repSpec != null && targetReps != null;

  bool allowedIn(Trimester t) => trimesters.contains(t);

  List<PostureRule> get rules => buildRules?.call() ?? const [];

  /// Rehberli egzersizin bir setinin toplam süresi.
  int get guidedSetSeconds =>
      guidedSteps.fold(0, (a, s) => a + s.seconds) * guidedRepeats;

  /// Bu egzersiz için yeni bir postür denetleyicisi oluşturur.
  FormChecker createChecker(
      {FormCheckerConfig config = const FormCheckerConfig()}) {
    if (!usesCamera) {
      throw StateError('$id kamera kullanmayan bir egzersiz');
    }
    return FormChecker(
      rules: rules,
      isBodyVisible: isBodyVisible ?? (_) => true,
      repSpec: repSpec,
      config: config,
    );
  }

  /// Tahmini süre (dakika, yuvarlanmış).
  int get estimatedMinutes {
    final perSet = switch (mode) {
      ExerciseMode.guided => guidedSetSeconds,
      ExerciseMode.camera => targetSeconds ?? (targetReps ?? 10) * 5,
    };
    final total = perSet * sets + restSeconds * (sets - 1);
    return (total / 60).ceil().clamp(1, 60);
  }

  /// Arayüzde kural kimliğine karşılık gelen kısa açıklama.
  String ruleLabel(String ruleId) {
    for (final r in rules) {
      if (r.id == ruleId) return r.label;
    }
    return ruleId;
  }
}
