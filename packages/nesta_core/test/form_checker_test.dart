import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

/// Tek ölçümlü sentetik kural: sağ dizin x konumu (0–100).
Pose _p(double v, {double likelihood = 0.9}) =>
    Pose({Joint.rightKnee: Landmark(v, 0, likelihood: likelihood)});

FormChecker _checker({RepSpec? rep}) => FormChecker(
      rules: [
        PostureRule(
          id: 'r',
          label: 'R',
          cue: 'düzelt',
          metric: (p) => p[Joint.rightKnee]?.x,
          max: 50,
        ),
      ],
      isBodyVisible: (p) => p[Joint.rightKnee] != null,
      repSpec: rep,
      config: const FormCheckerConfig(smoothing: 1),
    );

void main() {
  group('Geometry', () {
    test('dik açı', () {
      expect(
          Geometry.angle(const Landmark(0, 10), const Landmark(0, 0),
              const Landmark(10, 0)),
          closeTo(90, 1e-9));
    });
    test('düz çizgi 180 derece', () {
      expect(
          Geometry.angle(const Landmark(-5, 0), const Landmark(0, 0),
              const Landmark(5, 0)),
          closeTo(180, 1e-9));
    });
    test('düşey ve yatay sapma', () {
      expect(
          Geometry.angleFromVertical(
              const Landmark(0, 0), const Landmark(0, 10)),
          closeTo(0, 1e-9));
      expect(
          Geometry.angleFromVertical(
              const Landmark(0, 0), const Landmark(10, 10)),
          closeTo(45, 1e-9));
      expect(
          Geometry.angleFromHorizontal(
              const Landmark(0, 0), const Landmark(10, 0)),
          closeTo(0, 1e-9));
    });
    test('yükseklik açısı y ekseni aşağı doğru', () {
      // Hedef nokta yukarıda (küçük y) ise pozitif.
      expect(Geometry.elevation(const Landmark(0, 10), const Landmark(10, 0)),
          closeTo(45, 1e-9));
      expect(Geometry.elevation(const Landmark(0, 0), const Landmark(10, 10)),
          closeTo(-45, 1e-9));
    });
    test('düşük güvenli eklem görünmez sayılır', () {
      final p = Pose({Joint.nose: const Landmark(1, 1, likelihood: 0.3)});
      expect(p[Joint.nose], isNull);
    });
  });

  group('FormChecker', () {
    test('kısa süreli ihlal uyarı üretmez (debounce)', () {
      final c = _checker();
      expect(c.process(_p(10), 0).cue, isNull);
      expect(c.process(_p(60), 100).activeViolations, isEmpty);
      expect(c.process(_p(60), 500).activeViolations, isEmpty);
      final f = c.process(_p(10), 600);
      expect(f.activeViolations, isEmpty);
      expect(c.summary.violationCounts, isEmpty);
    });

    test('süren ihlal bir kez sayılır ve sesli uyarı verir', () {
      final c = _checker();
      c.process(_p(60), 0);
      final f = c.process(_p(60), 900);
      expect(f.activeViolations, ['r']);
      expect(f.cue, 'düzelt');
      expect(c.process(_p(60), 1500).cue, isNull, reason: 'bekleme süresi');
      expect(c.summary.violationCounts['r'], 1);
    });

    test('aynı kural için uyarı bekleme süresinden sonra tekrarlanır', () {
      final c = _checker();
      c.process(_p(60), 0);
      expect(c.process(_p(60), 900).cue, isNotNull);
      expect(c.process(_p(60), 5000).cue, isNull);
      expect(c.process(_p(60), 7000).cue, 'düzelt');
    });

    test('histerezis: sınıra dönmek ihlali bitirmez', () {
      final c = _checker();
      c.process(_p(60), 0);
      c.process(_p(60), 900);
      expect(c.process(_p(49), 1000).activeViolations, ['r']);
      expect(c.process(_p(45), 1100).activeViolations, isEmpty);
    });

    test('vücut görünmezse konumlanma uyarısı verilir', () {
      final c = _checker();
      expect(c.process(null, 0).cue, isNull);
      final f = c.process(null, 1600);
      expect(f.bodyVisible, isFalse);
      expect(f.cue, visibilityCue);
      expect(c.process(_p(10, likelihood: 0.2), 2000).bodyVisible, isFalse);
    });

    test('form puanı doğru geçen süreye göre hesaplanır', () {
      final c = _checker();
      var t = 0;
      for (var i = 0; i < 30; i++, t += 100) {
        c.process(_p(10), t);
      }
      for (var i = 0; i < 30; i++, t += 100) {
        c.process(_p(80), t);
      }
      final s = c.summary;
      // İhlal 800 ms sonra aktifleşir: 3000 + 800 doğru, 2200 hatalı.
      expect(s.formScore, inInclusiveRange(60, 68));
    });

    test('tekrar sayacı tam döngüleri sayar', () {
      final c = _checker(
          rep:
              RepSpec(metric: (p) => p[Joint.rightKnee]?.x, low: 20, high: 40));
      var t = 0;
      for (final v in <double>[45, 30, 15, 30, 45, 30, 15, 25, 15, 45]) {
        c.process(_p(v), t += 100);
      }
      expect(c.summary.reps, 2);
    });
  });
}
