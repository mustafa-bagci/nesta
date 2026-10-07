/// Gebelikte egzersiz sırasında nabız hedef aralıkları ve izleme mantığı.
///
/// Hedef aralıklar 2019 Kanada gebelikte fiziksel aktivite kılavuzunda
/// (Mottola ve ark., 2018) orta şiddetli aktivite için verilen değerlerdir.
/// Klinik ekip onayı olmadan değiştirilmemelidir.
library;

import 'dart:math' as math;

import '../models/records.dart';

class HeartRateZone {
  const HeartRateZone(this.low, this.high, this.source);

  final int low;
  final int high;

  /// Aralığın hangi kılavuz satırından geldiği (raporlama için).
  final String source;

  /// Bu değerin üzerindeki nabızda egzersiz durdurulur.
  int get stopThreshold => high + 15;

  /// Yaş ve gebelik öncesi BKİ'ye göre hedef aralık.
  static HeartRateZone forProfile({required int age, double? bmi}) {
    final overweight = bmi != null && bmi >= 25;
    if (overweight) {
      // Kılavuzdaki fazla kilolu/obez gebeler için aralıklar (20–39 yaş).
      return age < 30
          ? const HeartRateZone(110, 131, 'BKİ ≥ 25, 20–29 yaş')
          : const HeartRateZone(108, 127, 'BKİ ≥ 25, 30–39 yaş');
    }
    return age < 30
        ? const HeartRateZone(125, 146, 'BKİ < 25, 29 yaş ve altı')
        : const HeartRateZone(121, 141, 'BKİ < 25, 30 yaş ve üzeri');
  }

  @override
  String toString() => '$low–$high atım/dk';
}

enum HeartRateStatus {
  /// Saatten henüz veri gelmedi.
  noData,
  below,
  inZone,

  /// Hedefin üzerinde; tempoyu düşürme uyarısı verilir.
  above,

  /// Durdurma eşiği aşıldı; egzersiz duraklatılır.
  critical,
}

class HeartRateUpdate {
  const HeartRateUpdate(this.status,
      {this.bpm, this.cue, this.shouldStop = false});
  final HeartRateStatus status;
  final int? bpm;

  /// Sesli okunacak yeni uyarı varsa.
  final String? cue;

  /// Seans güvenlik nedeniyle durdurulmalı mı?
  final bool shouldStop;
}

/// Saatten gelen nabız örneklerini işleyerek uyarı ve durdurma kararı üretir.
class HeartRateMonitor {
  HeartRateMonitor(
    this.zone, {
    this.aboveWarnAfter = const Duration(seconds: 15),
    this.criticalStopAfter = const Duration(seconds: 10),
    this.sustainedAboveStopAfter = const Duration(seconds: 90),
    this.cueCooldown = const Duration(seconds: 30),
    this.staleAfter = const Duration(seconds: 30),
  });

  final HeartRateZone zone;
  final Duration aboveWarnAfter;
  final Duration criticalStopAfter;

  /// Hedefin üzerinde bu kadar kesintisiz kalınırsa da seans durdurulur.
  final Duration sustainedAboveStopAfter;
  final Duration cueCooldown;

  /// Bu süreden eski örnek "veri yok" sayılır.
  final Duration staleAfter;

  final List<int> _samples = [];
  DateTime? _lastSampleAt;
  DateTime? _aboveSince;
  DateTime? _criticalSince;
  DateTime? _lastCueAt;
  int? _lastBpm;
  int _secondsAboveZone = 0;

  int? get lastBpm => _lastBpm;

  HeartRateUpdate addSample(int bpm, DateTime at) {
    if (bpm < 30 || bpm > 230) {
      // Fizyolojik olmayan değer: sensör hatası olarak yok say.
      return status(at);
    }
    if (_lastSampleAt != null && _lastBpm != null && _lastBpm! > zone.high) {
      final gap = at.difference(_lastSampleAt!).inSeconds;
      _secondsAboveZone += math.min(gap, staleAfter.inSeconds);
    }
    _samples.add(bpm);
    _lastBpm = bpm;
    _lastSampleAt = at;

    if (bpm >= zone.stopThreshold) {
      _criticalSince ??= at;
    } else {
      _criticalSince = null;
    }
    if (bpm > zone.high) {
      _aboveSince ??= at;
    } else {
      _aboveSince = null;
    }

    if (_criticalSince != null &&
        at.difference(_criticalSince!) >= criticalStopAfter) {
      return HeartRateUpdate(HeartRateStatus.critical,
          bpm: bpm,
          shouldStop: true,
          cue: 'Nabzınız güvenli sınırın üzerinde. Egzersizi bırakın, '
              'oturun ve dinlenin.');
    }
    if (_aboveSince != null &&
        at.difference(_aboveSince!) >= sustainedAboveStopAfter) {
      return HeartRateUpdate(HeartRateStatus.above,
          bpm: bpm,
          shouldStop: true,
          cue: 'Nabzınız uzun süredir hedefin üzerinde. Egzersize ara verin '
              've dinlenin.');
    }
    if (_aboveSince != null && at.difference(_aboveSince!) >= aboveWarnAfter) {
      String? cue;
      if (_lastCueAt == null || at.difference(_lastCueAt!) >= cueCooldown) {
        cue = 'Nabzınız hedefin üzerinde. Lütfen tempoyu düşürün ve '
            'derin nefes alın.';
        _lastCueAt = at;
      }
      return HeartRateUpdate(HeartRateStatus.above, bpm: bpm, cue: cue);
    }
    return HeartRateUpdate(
        bpm > zone.high
            ? HeartRateStatus.above
            : bpm < zone.low
                ? HeartRateStatus.below
                : HeartRateStatus.inZone,
        bpm: bpm);
  }

  HeartRateUpdate status(DateTime now) {
    if (_lastSampleAt == null ||
        now.difference(_lastSampleAt!) > staleAfter ||
        _lastBpm == null) {
      return const HeartRateUpdate(HeartRateStatus.noData);
    }
    final b = _lastBpm!;
    return HeartRateUpdate(
        b >= zone.stopThreshold
            ? HeartRateStatus.critical
            : b > zone.high
                ? HeartRateStatus.above
                : b < zone.low
                    ? HeartRateStatus.below
                    : HeartRateStatus.inZone,
        bpm: b);
  }

  HeartRateSummary? summary() {
    if (_samples.isEmpty) return null;
    final sum = _samples.fold<int>(0, (a, b) => a + b);
    return HeartRateSummary(
      min: _samples.reduce(math.min),
      avg: (sum / _samples.length).round(),
      max: _samples.reduce(math.max),
      sampleCount: _samples.length,
      secondsAboveZone: _secondsAboveZone,
      zoneLow: zone.low,
      zoneHigh: zone.high,
    );
  }
}

/// Borg algılanan zorlanma ölçeği (6–20). Gebelikte orta şiddet 12–14'tür.
const borgScale = <int, String>{
  6: 'Hiç zorlanmıyorum',
  7: 'Son derece hafif',
  8: 'Son derece hafif',
  9: 'Çok hafif',
  10: 'Çok hafif',
  11: 'Hafif',
  12: 'Biraz zor',
  13: 'Biraz zor',
  14: 'Biraz zor',
  15: 'Zor',
  16: 'Zor',
  17: 'Çok zor',
  18: 'Çok zor',
  19: 'Son derece zor',
  20: 'Tükendim',
};

bool isModerateRpe(int rpe) => rpe >= 12 && rpe <= 14;

/// Nabız eşiği kullanılamayan gebeler (ör. beta bloker) için konuşma testi
/// hatırlatması.
const talkTestCue =
    'Konuşma testi: Şu an rahatça konuşabiliyor musunuz? Konuşmakta '
    'zorlanıyorsanız tempoyu düşürün.';
