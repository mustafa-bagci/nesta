import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';

import '../theme.dart';

/// Kamera görüntüsünün üzerine iskeleti çizer; ihlal edilen kuralla ilgili
/// eklemler kırmızı gösterilir.
class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.mirrored,
    required this.correct,
  });

  final Pose? pose;
  final Size imageSize;
  final bool mirrored;
  final bool correct;

  static const _bones = [
    (Joint.leftShoulder, Joint.rightShoulder),
    (Joint.leftHip, Joint.rightHip),
    (Joint.leftShoulder, Joint.leftHip),
    (Joint.rightShoulder, Joint.rightHip),
    (Joint.leftShoulder, Joint.leftElbow),
    (Joint.leftElbow, Joint.leftWrist),
    (Joint.rightShoulder, Joint.rightElbow),
    (Joint.rightElbow, Joint.rightWrist),
    (Joint.leftHip, Joint.leftKnee),
    (Joint.leftKnee, Joint.leftAnkle),
    (Joint.rightHip, Joint.rightKnee),
    (Joint.rightKnee, Joint.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    if (p == null || imageSize.isEmpty) return;
    Offset map(Landmark l) {
      final x = l.x * size.width / imageSize.width;
      return Offset(
        mirrored ? size.width - x : x,
        l.y * size.height / imageSize.height,
      );
    }

    final color = correct ? NestaColors.mint : NestaColors.peach;
    final bone = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final (a, b) in _bones) {
      final la = p[a], lb = p[b];
      if (la != null && lb != null) canvas.drawLine(map(la), map(lb), bone);
    }
    for (final (a, b) in _bones) {
      for (final j in [a, b]) {
        final l = p[j];
        if (l == null) continue;
        canvas.drawCircle(map(l), 6, dot);
        canvas.drawCircle(map(l), 6, ring);
      }
    }
  }

  @override
  bool shouldRepaint(PoseOverlayPainter old) =>
      old.pose != pose || old.correct != correct || old.mirrored != mirrored;
}
