import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';

import '../theme.dart';

/// Egzersizin demo karelerinden canlandırılan gebe figürü.
///
/// Görsel varlık dosyası gerektirmez; aynı kareler postür kurallarının
/// testlerinde de kullanıldığı için çizim ile kurallar her zaman tutarlıdır.
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure({
    super.key,
    required this.exercise,
    this.animate = true,
    this.color,
    this.period = const Duration(milliseconds: 2400),
  });

  final Exercise exercise;
  final bool animate;
  final Color? color;
  final Duration period;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ExerciseFigure old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.exercise.demoFrames;
    final color =
        widget.color ?? NestaColors.forKey(widget.exercise.colorKey).$1;
    if (frames.length < 2) {
      return Center(
        child: Icon(
          widget.exercise.category == ExerciseCategory.breathing
              ? Icons.air_rounded
              : Icons.self_improvement_rounded,
          size: 64,
          color: color,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return CustomPaint(
          painter: _FigurePainter(
            _lerp(frames.first, frames.last, t),
            color: color,
            view: widget.exercise.cameraView,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  static DemoFrame _lerp(DemoFrame a, DemoFrame b, double t) => {
    for (final j in a.keys)
      if (b.containsKey(j))
        j: (
          a[j]!.$1 + (b[j]!.$1 - a[j]!.$1) * t,
          a[j]!.$2 + (b[j]!.$2 - a[j]!.$2) * t,
        ),
  };
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.frame, {required this.color, this.view});

  final DemoFrame frame;
  final Color color;
  final CameraView? view;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final dx = (size.width - s) / 2, dy = (size.height - s) / 2;
    Offset? p(Joint j) {
      final v = frame[j];
      return v == null ? null : Offset(dx + v.$1 * s, dy + v.$2 * s);
    }

    final limb = Paint()
      ..color = color
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final far = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final skin = Paint()..color = const Color(0xFFF2C6A7);
    final body = Paint()..color = color;

    void chain(List<Joint> joints, Paint paint) {
      for (var i = 0; i < joints.length - 1; i++) {
        final a = p(joints[i]), b = p(joints[i + 1]);
        if (a != null && b != null) canvas.drawLine(a, b, paint);
      }
    }

    final isSide = view == CameraView.side;
    // Yandan görünümde uzak taraf açık renkte, önce çizilir.
    final farPaint = isSide ? far : limb;
    chain([Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist], farPaint);
    chain([Joint.rightHip, Joint.rightKnee, Joint.rightAnkle], farPaint);

    // Gövde
    final ls = p(Joint.leftShoulder), rs = p(Joint.rightShoulder);
    final lh = p(Joint.leftHip), rh = p(Joint.rightHip);
    if (ls != null && rs != null && lh != null && rh != null) {
      final torso = Path()
        ..moveTo(ls.dx, ls.dy)
        ..lineTo(rs.dx, rs.dy)
        ..lineTo(rh.dx, rh.dy)
        ..lineTo(lh.dx, lh.dy)
        ..close();
      canvas.drawPath(
        torso,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(torso, body);
      _belly(canvas, s, ls, rs, lh, rh, isSide);
    }

    chain([Joint.leftHip, Joint.leftKnee, Joint.leftAnkle], limb);
    chain([Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist], limb);

    // Baş
    final nose = p(Joint.nose);
    if (nose != null && ls != null && rs != null) {
      final neck = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);
      final head = Offset.lerp(neck, nose, 0.85)!;
      canvas.drawLine(neck, head, limb..strokeWidth = s * 0.035);
      canvas.drawCircle(head, s * 0.055, skin);
      // Saç topuzu
      final away = (head - nose);
      final bun =
          head +
          (away.distance == 0
              ? Offset(0, -s * 0.05)
              : away / away.distance * s * 0.05) +
          Offset(0, -s * 0.02);
      canvas.drawCircle(
        bun,
        s * 0.028,
        Paint()..color = const Color(0xFF5B4636),
      );
    }
  }

  void _belly(
    Canvas canvas,
    double s,
    Offset ls,
    Offset rs,
    Offset lh,
    Offset rh,
    bool isSide,
  ) {
    final shoulder = Offset.lerp(ls, rs, 0.5)!;
    final hip = Offset.lerp(lh, rh, 0.5)!;
    final center = Offset.lerp(shoulder, hip, 0.68)!;
    final axis = hip - shoulder;
    if (axis.distance == 0) return;
    final paint = Paint()..color = Color.lerp(color, Colors.white, 0.25)!;
    if (isSide) {
      // Karın, gövdenin ön tarafına doğru (başın baktığı yöne) çıkıntı yapar.
      final noseX = frame[Joint.nose]?.$1;
      final forward = noseX == null || noseX * s >= shoulder.dx - 1
          ? 1.0
          : -1.0;
      var normal = Offset(-axis.dy, axis.dx) / axis.distance;
      // Normalin aşağı (yere) doğru olanını seç: dört ayak ve ayakta duruş için.
      if (normal.dy < 0) normal = -normal;
      if (axis.dy.abs() > axis.dx.abs()) {
        normal = Offset(forward, 0);
      }
      canvas.drawCircle(center + normal * s * 0.045, s * 0.07, paint);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: s * 0.13, height: s * 0.12),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.frame != frame || old.color != color;
}
