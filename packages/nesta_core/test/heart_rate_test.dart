import 'package:nesta_core/nesta_core.dart';
import 'package:test/test.dart';

void main() {
  group('HeartRateZone', () {
    test('yaş ve BKİ\'ye göre kılavuz aralıkları', () {
      expect(HeartRateZone.forProfile(age: 25).low, 125);
      expect(HeartRateZone.forProfile(age: 25).high, 146);
      expect(HeartRateZone.forProfile(age: 33, bmi: 22).high, 141);
      expect(HeartRateZone.forProfile(age: 25, bmi: 28).high, 131);
      expect(HeartRateZone.forProfile(age: 35, bmi: 31).low, 108);
    });
  });

  group('HeartRateMonitor', () {
    final zone = HeartRateZone.forProfile(age: 31); // 121–141, durdurma 156
    final t0 = DateTime.utc(2026, 10, 7, 10);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('veri yokken durum noData', () {
      final m = HeartRateMonitor(zone);
      expect(m.status(t0).status, HeartRateStatus.noData);
      m.addSample(120, t0);
      expect(m.status(at(10)).status, HeartRateStatus.below);
      expect(m.status(at(60)).status, HeartRateStatus.noData);
    });

    test('hedef üstü 15 sn sürerse bir kez uyarır', () {
      final m = HeartRateMonitor(zone);
      expect(m.addSample(145, at(0)).cue, isNull);
      expect(m.addSample(146, at(10)).cue, isNull);
      final u = m.addSample(147, at(16));
      expect(u.status, HeartRateStatus.above);
      expect(u.cue, isNotNull);
      expect(u.shouldStop, isFalse);
      expect(m.addSample(147, at(20)).cue, isNull, reason: 'bekleme süresi');
    });

    test('kritik eşik 10 sn sürerse durdurur', () {
      final m = HeartRateMonitor(zone);
      expect(m.addSample(160, at(0)).shouldStop, isFalse);
      final u = m.addSample(161, at(11));
      expect(u.status, HeartRateStatus.critical);
      expect(u.shouldStop, isTrue);
    });

    test('hedefe dönünce sayaç sıfırlanır', () {
      final m = HeartRateMonitor(zone);
      m.addSample(150, at(0));
      m.addSample(130, at(10));
      expect(m.addSample(150, at(20)).cue, isNull);
      expect(m.addSample(150, at(30)).cue, isNull);
    });

    test('uzun süre hedef üstünde kalınca durdurur', () {
      final m = HeartRateMonitor(zone);
      HeartRateUpdate? last;
      for (var s = 0; s <= 100; s += 5) {
        last = m.addSample(148, at(s));
      }
      expect(last!.shouldStop, isTrue);
    });

    test('fizyolojik olmayan örnekler yok sayılır ve özet hesaplanır', () {
      final m = HeartRateMonitor(zone);
      m.addSample(100, at(0));
      m.addSample(250, at(5));
      m.addSample(150, at(10));
      m.addSample(120, at(20));
      final s = m.summary()!;
      expect(s.min, 100);
      expect(s.max, 150);
      expect(s.avg, 123);
      expect(s.sampleCount, 3);
      expect(s.secondsAboveZone, 10);
      expect(s.zoneHigh, 141);
    });
  });

  test('Borg ölçeği 6–20 arasını kapsar', () {
    expect(borgScale.keys, containsAll(List.generate(15, (i) => i + 6)));
    expect(isModerateRpe(13), isTrue);
    expect(isModerateRpe(16), isFalse);
  });
}
