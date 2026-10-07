import 'dart:io';

import 'package:nesta_core/nesta_core.dart';
import 'package:path_provider/path_provider.dart';

/// Araştırma modu: teknik doğrulama ve veri seti oluşturma için her karenin
/// eklem koordinatlarını, kural ölçümlerini ve uyarılarını CSV'ye yazar.
///
/// Dosyalar yalnızca telefonda saklanır; görüntü içermez.
class FrameLogger {
  FrameLogger._(this.file, this._sink, this._rules);

  final File file;
  final IOSink _sink;
  final List<PostureRule> _rules;

  static const _joints = [
    Joint.nose,
    Joint.leftShoulder,
    Joint.rightShoulder,
    Joint.leftElbow,
    Joint.rightElbow,
    Joint.leftWrist,
    Joint.rightWrist,
    Joint.leftHip,
    Joint.rightHip,
    Joint.leftKnee,
    Joint.rightKnee,
    Joint.leftAnkle,
    Joint.rightAnkle,
  ];

  static Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/kare_kayitlari').create(recursive: true);
  }

  static Future<List<File>> files() async {
    final dir = await directory();
    final list =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.csv'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return list;
  }

  static Future<FrameLogger> start(Exercise exercise, {DateTime? now}) async =>
      startIn(await directory(), exercise, now: now);

  static Future<FrameLogger> startIn(
    Directory dir,
    Exercise exercise, {
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now())
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final file = File('${dir.path}/nesta_kare_${exercise.id}_$t.csv');
    final sink = file.openWrite();
    final rules = exercise.rules;
    sink.writeln(
      [
        't_ms',
        'goruntu_genislik',
        'goruntu_yukseklik',
        'govde_gorunur',
        'tekrar',
        'ihlaller',
        for (final r in rules) 'olcum_${r.id}',
        for (final j in _joints) ...[
          '${j.name}_x',
          '${j.name}_y',
          '${j.name}_p',
        ],
      ].join(','),
    );
    return FrameLogger._(file, sink, rules);
  }

  void add({
    required int tMs,
    required double imageWidth,
    required double imageHeight,
    required Pose? pose,
    required FormFeedback? feedback,
  }) {
    String n(double? v) => v == null ? '' : v.toStringAsFixed(2);
    _sink.writeln(
      [
        tMs,
        imageWidth.toStringAsFixed(0),
        imageHeight.toStringAsFixed(0),
        (feedback?.bodyVisible ?? false) ? 1 : 0,
        feedback?.reps ?? 0,
        feedback?.activeViolations.join('|') ?? '',
        for (final r in _rules) n(feedback?.values[r.id]),
        for (final j in _joints) ...[
          n(pose?.landmarks[j]?.x),
          n(pose?.landmarks[j]?.y),
          n(pose?.landmarks[j]?.likelihood),
        ],
      ].join(','),
    );
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
