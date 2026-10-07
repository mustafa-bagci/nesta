/// Postür kuralları, tekrar sayacı ve anlık geri bildirim üreten motor.
library;

import 'pose.dart';

/// Bir pozdan sayısal bir ölçüm (ör. diz açısı) çıkarır. Gerekli eklemler
/// görünmüyorsa `null` döner.
typedef Metric = double? Function(Pose pose);

/// Ölçümün izin verilen aralıkta kalmasını bekleyen postür kuralı.
class PostureRule {
  const PostureRule({
    required this.id,
    required this.label,
    required this.cue,
    required this.metric,
    this.min,
    this.max,
    this.hysteresis = 4,
  }) : assert(min != null || max != null);

  final String id;

  /// Ekranda gösterilen kısa açıklama (ör. "Gövde dik").
  final String label;

  /// Sesli okunan düzeltme cümlesi.
  final String cue;
  final Metric metric;
  final double? min;
  final double? max;

  /// İhlalin "düzeldi" sayılması için aralığın ne kadar içine dönülmesi
  /// gerektiği; sınırda titreşen değerlerin sürekli uyarı üretmesini önler.
  final double hysteresis;

  bool isOutside(double v) =>
      (min != null && v < min!) || (max != null && v > max!);

  bool isSafelyInside(double v) =>
      (min == null || v >= min! + hysteresis) &&
      (max == null || v <= max! - hysteresis);
}

/// Tekrar sayımı için kullanılan ölçüm ve eşikler.
///
/// [startsHigh] true ise hareket yüksek değerden başlar (ör. ayakta diz açısı
/// ~180°), [low] altına inip tekrar [high] üstüne çıkınca bir tekrar sayılır.
class RepSpec {
  const RepSpec({
    required this.metric,
    required this.low,
    required this.high,
    this.startsHigh = true,
  }) : assert(low < high);

  final Metric metric;
  final double low;
  final double high;
  final bool startsHigh;
}

class RepCounter {
  RepCounter(this.spec);
  final RepSpec spec;

  int count = 0;
  bool _inMiddleOfRep = false;

  /// Yeni bir tekrar tamamlandıysa true döner.
  bool update(double value) {
    if (spec.startsHigh) {
      if (!_inMiddleOfRep && value < spec.low) {
        _inMiddleOfRep = true;
      } else if (_inMiddleOfRep && value > spec.high) {
        _inMiddleOfRep = false;
        count++;
        return true;
      }
    } else {
      if (!_inMiddleOfRep && value > spec.high) {
        _inMiddleOfRep = true;
      } else if (_inMiddleOfRep && value < spec.low) {
        _inMiddleOfRep = false;
        count++;
        return true;
      }
    }
    return false;
  }
}

/// Tek bir kare için üretilen geri bildirim.
class FormFeedback {
  const FormFeedback({
    required this.bodyVisible,
    required this.activeViolations,
    required this.reps,
    required this.values,
    this.cue,
    this.repCompleted = false,
  });

  final bool bodyVisible;

  /// Şu an ihlal edilen kuralların kimlikleri.
  final List<String> activeViolations;
  final int reps;

  /// Kural kimliği → yumuşatılmış ölçüm değeri.
  final Map<String, double> values;

  /// Sesli okunması gereken yeni bir uyarı varsa.
  final String? cue;
  final bool repCompleted;

  bool get isCorrect => bodyVisible && activeViolations.isEmpty;
}

/// Seans sonunda kaydedilen form özeti.
class FormSummary {
  const FormSummary({
    required this.reps,
    required this.violationCounts,
    required this.visibleMs,
    required this.correctMs,
  });

  final int reps;
  final Map<String, int> violationCounts;
  final int visibleMs;
  final int correctMs;

  /// Vücudun göründüğü sürenin yüzde kaçı doğru postürde geçti.
  int? get formScore =>
      visibleMs < 1000 ? null : (100 * correctMs / visibleMs).round();
}

class FormCheckerConfig {
  const FormCheckerConfig({
    this.smoothing = 0.4,
    this.debounceMs = 800,
    this.ruleCooldownMs = 6000,
    this.minCueGapMs = 2500,
    this.notVisibleMs = 1500,
  });

  /// Üstel hareketli ortalama katsayısı (1 = yumuşatma yok).
  final double smoothing;

  /// İhlalin uyarıya dönüşmesi için kesintisiz sürmesi gereken süre.
  final int debounceMs;

  /// Aynı kural için iki sesli uyarı arasındaki en kısa süre.
  final int ruleCooldownMs;

  /// Herhangi iki sesli uyarı arasındaki en kısa süre.
  final int minCueGapMs;

  /// Vücut bu süre boyunca görünmezse konumlanma uyarısı verilir.
  final int notVisibleMs;
}

const visibilityCue =
    'Lütfen tüm vücudunuz kamerada görünecek şekilde konumlanın.';

/// Kareleri sırayla işleyerek postür ihlallerini, tekrarları ve sesli
/// uyarıları üretir. Durum taşıdığı için her seans için yeni örnek oluşturulur.
class FormChecker {
  FormChecker({
    required this.rules,
    required this.isBodyVisible,
    this.repSpec,
    this.config = const FormCheckerConfig(),
  }) : _repCounter = repSpec == null ? null : RepCounter(repSpec);

  final List<PostureRule> rules;

  /// Karede egzersiz için gereken eklemlerin görünüp görünmediği.
  final bool Function(Pose pose) isBodyVisible;
  final RepSpec? repSpec;
  final FormCheckerConfig config;
  final RepCounter? _repCounter;

  final Map<String, double> _smoothed = {};
  final Map<String, int> _outsideSince = {};
  final Set<String> _active = {};
  final Map<String, int> _lastRuleCue = {};
  final Map<String, int> _violationCounts = {};
  double? _repSmoothed;
  int? _lastCueAt;
  int? _notVisibleSince;
  int? _lastFrameAt;
  int _visibleMs = 0;
  int _correctMs = 0;

  FormSummary get summary => FormSummary(
        reps: _repCounter?.count ?? 0,
        violationCounts: Map.unmodifiable(_violationCounts),
        visibleMs: _visibleMs,
        correctMs: _correctMs,
      );

  double _smooth(double? prev, double v) =>
      prev == null ? v : prev + config.smoothing * (v - prev);

  bool _canCue(int t) =>
      _lastCueAt == null || t - _lastCueAt! >= config.minCueGapMs;

  /// [pose] null ise karede kişi bulunamamıştır. [tMs] artan zaman damgasıdır.
  FormFeedback process(Pose? pose, int tMs) {
    final dt =
        _lastFrameAt == null ? 0 : (tMs - _lastFrameAt!).clamp(0, 1000).toInt();
    _lastFrameAt = tMs;

    final visible = pose != null && isBodyVisible(pose);
    if (!visible) {
      _notVisibleSince ??= tMs;
      _outsideSince.clear();
      _active.clear();
      String? cue;
      if (tMs - _notVisibleSince! >= config.notVisibleMs &&
          _canCue(tMs) &&
          (_lastRuleCue['_visibility'] == null ||
              tMs - _lastRuleCue['_visibility']! >= config.ruleCooldownMs)) {
        cue = visibilityCue;
        _lastCueAt = tMs;
        _lastRuleCue['_visibility'] = tMs;
      }
      return FormFeedback(
        bodyVisible: false,
        activeViolations: const [],
        reps: _repCounter?.count ?? 0,
        values: Map.unmodifiable(_smoothed),
        cue: cue,
      );
    }
    _notVisibleSince = null;

    String? cue;
    for (final rule in rules) {
      final raw = rule.metric(pose);
      if (raw == null) continue;
      final v = _smoothed[rule.id] = _smooth(_smoothed[rule.id], raw);

      if (_active.contains(rule.id)) {
        if (rule.isSafelyInside(v)) {
          _active.remove(rule.id);
          _outsideSince.remove(rule.id);
        }
      } else if (rule.isOutside(v)) {
        final since = _outsideSince.putIfAbsent(rule.id, () => tMs);
        if (tMs - since >= config.debounceMs) {
          _active.add(rule.id);
          _violationCounts[rule.id] = (_violationCounts[rule.id] ?? 0) + 1;
        }
      } else {
        _outsideSince.remove(rule.id);
      }

      if (cue == null && _active.contains(rule.id) && _canCue(tMs)) {
        final last = _lastRuleCue[rule.id];
        if (last == null || tMs - last >= config.ruleCooldownMs) {
          cue = rule.cue;
          _lastCueAt = tMs;
          _lastRuleCue[rule.id] = tMs;
        }
      }
    }

    var repCompleted = false;
    final counter = _repCounter;
    if (counter != null) {
      final raw = counter.spec.metric(pose);
      if (raw != null) {
        _repSmoothed = _smooth(_repSmoothed, raw);
        repCompleted = counter.update(_repSmoothed!);
      }
    }

    _visibleMs += dt;
    if (_active.isEmpty) _correctMs += dt;

    return FormFeedback(
      bodyVisible: true,
      activeViolations: rules
          .where((r) => _active.contains(r.id))
          .map((r) => r.id)
          .toList(growable: false),
      reps: counter?.count ?? 0,
      values: Map.unmodifiable(_smoothed),
      cue: cue,
      repCompleted: repCompleted,
    );
  }
}
