import 'dart:async';

import 'package:nesta/services/heart_rate_source.dart';
import 'package:nesta/services/voice_coach.dart';

class FakeSpeaker implements Speaker {
  final said = <String>[];

  @override
  Future<void> init({required double rate}) async {}

  @override
  Future<void> say(String text, {bool interrupt = false}) async =>
      said.add(text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class FakeHeartRate implements HeartRateSource {
  final controller = StreamController<int>.broadcast();
  bool stopped = false;

  @override
  String get name => 'Sahte';

  @override
  Future<HeartRateAvailability> prepare() async => HeartRateAvailability.ready;

  @override
  Stream<int> start() => controller.stream;

  @override
  Future<void> stop() async => stopped = true;
}

/// Elle ilerletilen saat.
class FakeClock {
  DateTime t = DateTime(2026, 10, 7, 10);
  DateTime call() => t;
  void advance(Duration d) => t = t.add(d);
}
