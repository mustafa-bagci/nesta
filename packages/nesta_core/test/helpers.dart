import 'package:nesta_core/nesta_core.dart';

/// Normalize demo karesini 720x720 piksel görüntüde bir poza çevirir.
Pose poseFrom(DemoFrame f, {double size = 720, Set<Joint> hidden = const {}}) =>
    Pose({
      for (final e in f.entries)
        e.key: Landmark(e.value.$1 * size, e.value.$2 * size,
            likelihood: hidden.contains(e.key) ? 0.1 : 0.95),
    });

DemoFrame lerpFrame(DemoFrame a, DemoFrame b, double t) => {
      for (final j in a.keys)
        if (b.containsKey(j))
          j: (
            a[j]!.$1 + (b[j]!.$1 - a[j]!.$1) * t,
            a[j]!.$2 + (b[j]!.$2 - a[j]!.$2) * t,
          ),
    };

/// Başlangıç → uç → başlangıç döngüsünü [cycles] kez, saniyede [fps] kare
/// ile oynatır. Her yarım döngü [halfMs] sürer, uçlarda [holdMs] beklenir.
Iterable<(Pose, int)> playDemo(List<DemoFrame> frames,
    {int cycles = 3,
    int fps = 30,
    int halfMs = 1500,
    int holdMs = 600,
    DemoFrame Function(DemoFrame)? transform}) sync* {
  final step = 1000 ~/ fps;
  var t = 0;
  final a = frames.first, b = frames.last;
  Iterable<DemoFrame> segment(DemoFrame from, DemoFrame to) sync* {
    for (var ms = 0; ms < halfMs; ms += step) {
      yield lerpFrame(from, to, ms / halfMs);
    }
    for (var ms = 0; ms < holdMs; ms += step) {
      yield to;
    }
  }

  for (var c = 0; c < cycles; c++) {
    for (final f in [...segment(a, b), ...segment(b, a)]) {
      yield (poseFrom(transform == null ? f : transform(f)), t);
      t += step;
    }
  }
}
