import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:health/health.dart';

enum HeartRateAvailability {
  ready('Bağlı'),
  healthConnectMissing('Health Connect uygulaması yüklü değil'),
  permissionDenied('Nabız verisine erişim izni verilmedi'),
  unsupported('Bu cihaz desteklenmiyor');

  const HeartRateAvailability(this.label);
  final String label;
}

/// Seans sırasında nabız örnekleri sağlayan kaynak.
abstract class HeartRateSource {
  String get name;

  /// İzinleri ister ve kaynağın kullanılabilir olup olmadığını döndürür.
  Future<HeartRateAvailability> prepare();
  Stream<int> start();
  Future<void> stop();
}

/// Akıllı saatin Health Connect (Android) veya Apple Sağlık'a (iOS) yazdığı
/// nabız verisini okur.
///
/// Saatler veriyi telefona birkaç saniye ile birkaç dakika arası gecikmeyle
/// aktarabilir; bu nedenle yalnızca son iki dakikadaki en yeni örnek kullanılır.
class HealthHeartRateSource implements HeartRateSource {
  HealthHeartRateSource({this.pollInterval = const Duration(seconds: 5)});

  final Duration pollInterval;
  final Health _health = Health();
  Timer? _timer;
  StreamController<int>? _controller;
  DateTime? _lastSampleAt;

  static const _types = [HealthDataType.HEART_RATE];

  @override
  String get name => Platform.isIOS ? 'Apple Sağlık' : 'Health Connect';

  @override
  Future<HeartRateAvailability> prepare() async {
    try {
      await _health.configure();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          return HeartRateAvailability.healthConnectMissing;
        }
      }
      final granted = await _health.requestAuthorization(
        _types,
        permissions: const [HealthDataAccess.READ],
      );
      return granted
          ? HeartRateAvailability.ready
          : HeartRateAvailability.permissionDenied;
    } catch (_) {
      return HeartRateAvailability.unsupported;
    }
  }

  /// Android'de Health Connect'i yükleme sayfasını açar.
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Stream<int> start() {
    _controller?.close();
    final c = _controller = StreamController<int>.broadcast();
    _lastSampleAt = DateTime.now().subtract(const Duration(minutes: 2));
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    _poll();
    return c.stream;
  }

  Future<void> _poll() async {
    final now = DateTime.now();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: now.subtract(const Duration(minutes: 2)),
        endTime: now,
      );
      points.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      for (final p in points) {
        if (!p.dateTo.isAfter(_lastSampleAt!)) continue;
        final v = p.value;
        if (v is NumericHealthValue) {
          _lastSampleAt = p.dateTo;
          _controller?.add(v.numericValue.round());
        }
      }
    } catch (_) {
      // Geçici okuma hatası: sonraki denemede tekrar okunur.
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }
}

/// Demo modunda ve saat bağlı değilken sunum amaçlı nabız üretir.
///
/// Nabız dinlenme değerinden hedef aralığa doğru yavaşça yükselir;
/// [spike] çağrılırsa güvenlik uyarısını göstermek için hızla yükselir.
class SimulatedHeartRateSource implements HeartRateSource {
  SimulatedHeartRateSource({
    this.interval = const Duration(seconds: 3),
    this.resting = 88,
    this.working = 126,
    Random? random,
  }) : _random = random ?? Random();

  final Duration interval;
  final int resting;
  final int working;
  final Random _random;
  Timer? _timer;
  StreamController<int>? _controller;
  double _current = 0;
  double _target = 0;

  @override
  String get name => 'Simülasyon (demo)';

  @override
  Future<HeartRateAvailability> prepare() async => HeartRateAvailability.ready;

  void spike() => _target = 168;

  void calmDown() => _target = working.toDouble();

  @override
  Stream<int> start() {
    _controller?.close();
    final c = _controller = StreamController<int>.broadcast();
    _current = resting.toDouble();
    _target = working.toDouble();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final step = (_target - _current) * 0.25;
      _current += step + (_random.nextDouble() * 4 - 2);
      c.add(_current.round());
    });
    return c.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }
}
