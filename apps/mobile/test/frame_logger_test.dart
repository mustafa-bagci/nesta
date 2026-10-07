import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nesta/services/frame_logger.dart';
import 'package:nesta_core/nesta_core.dart';

void main() {
  test('kare kaydı başlık, ölçüm ve eklem sütunlarını yazar', () async {
    final dir = await Directory.systemTemp.createTemp('nesta_kare');
    addTearDown(() => dir.delete(recursive: true));
    final e = supportedPlieSquat;
    final logger = await FrameLogger.startIn(
      dir,
      e,
      now: DateTime(2026, 10, 7, 9),
    );
    final checker = e.createChecker();
    final pose = Pose({
      for (final j in e.demoFrames.first.entries)
        j.key: Landmark(j.value.$1 * 720, j.value.$2 * 720, likelihood: 0.9),
    });
    logger.add(
      tMs: 0,
      imageWidth: 720,
      imageHeight: 1280,
      pose: pose,
      feedback: checker.process(pose, 0),
    );
    logger.add(
      tMs: 33,
      imageWidth: 720,
      imageHeight: 1280,
      pose: null,
      feedback: null,
    );
    await logger.close();

    final lines = logger.file.readAsLinesSync();
    expect(
      logger.file.path,
      contains('nesta_kare_destekli_plie_squat_2026-10-07T09-00-00'),
    );
    expect(lines, hasLength(3));
    final header = lines.first.split(',');
    expect(header.take(6), [
      't_ms',
      'goruntu_genislik',
      'goruntu_yukseklik',
      'govde_gorunur',
      'tekrar',
      'ihlaller',
    ]);
    expect(
      header,
      containsAll([
        'olcum_cok_derin',
        'olcum_dizler_ice',
        'olcum_govde_dik',
        'leftKnee_x',
        'rightAnkle_p',
      ]),
    );
    final row = lines[1].split(',');
    expect(row.length, header.length);
    expect(row[3], '1');
    expect(double.parse(row[header.indexOf('olcum_govde_dik')]), lessThan(1));
    expect(
      double.parse(row[header.indexOf('leftKnee_x')]),
      closeTo(0.63 * 720, 0.01),
    );
    expect(lines[2].split(',').length, header.length);
  });
}
