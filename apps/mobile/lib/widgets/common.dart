import 'package:flutter/material.dart';

import '../theme.dart';

/// Nesta logosu: kalp içinde filiz.
class NestaLogo extends StatelessWidget {
  const NestaLogo({super.key, this.size = 56, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      ),
      if (showName) ...[
        const SizedBox(height: 6),
        Text(
          'Nesta',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: NestaColors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ],
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final heart = Path()
      ..moveTo(w * 0.5, h * 0.9)
      ..cubicTo(w * 0.05, h * 0.6, w * 0.0, h * 0.25, w * 0.27, h * 0.18)
      ..cubicTo(w * 0.4, h * 0.14, w * 0.48, h * 0.24, w * 0.5, h * 0.3)
      ..cubicTo(w * 0.52, h * 0.24, w * 0.6, h * 0.14, w * 0.73, h * 0.18)
      ..cubicTo(w * 1.0, h * 0.25, w * 0.95, h * 0.6, w * 0.5, h * 0.9)
      ..close();
    canvas.drawPath(heart, Paint()..color = NestaColors.peach);
    final leaf = Paint()..color = NestaColors.primary;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.72),
      Offset(w * 0.5, h * 0.42),
      leaf
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );
    final l1 = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.3, h * 0.45, w * 0.32, h * 0.3)
      ..quadraticBezierTo(w * 0.48, h * 0.33, w * 0.5, h * 0.5);
    final l2 = Path()
      ..moveTo(w * 0.5, h * 0.44)
      ..quadraticBezierTo(w * 0.7, h * 0.4, w * 0.68, h * 0.24)
      ..quadraticBezierTo(w * 0.52, h * 0.27, w * 0.5, h * 0.44);
    canvas.drawPath(l1, Paint()..color = NestaColors.mint);
    canvas.drawPath(l2, Paint()..color = NestaColors.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Renkli bilgi kutusu.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = NestaColors.sky,
    this.background = NestaColors.skySoft,
    this.title,
  });

  final String text;
  final String? title;
  final IconData icon;
  final Color color;
  final Color background;

  const InfoBanner.warning({super.key, required this.text, this.title})
    : icon = Icons.warning_amber_rounded,
      color = NestaColors.danger,
      background = NestaColors.dangerSoft;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(text, style: const TextStyle(height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Numaralı adım satırı (egzersiz ekranındaki 01, 02, 03 kutuları).
class StepTile extends StatelessWidget {
  const StepTile({
    super.key,
    required this.index,
    required this.text,
    required this.color,
  });
  final int index;
  final String text;
  final (Color, Color) color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.$2,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          index.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color.$1,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

/// Ekranın altına sabitlenmiş birincil buton alanı.
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: child,
    ),
  );
}

/// Asenkron bir işlem sürerken butonu kilitleyen ve hata gösteren yardımcı.
Future<void> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: NestaColors.danger,
      ),
    );
  }
}

/// Uzun süren işlemler için butonda yükleniyor göstergesi.
class BusyButton extends StatefulWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await runWithFeedback(context, widget.onPressed!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final child = _busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(widget.label);
    if (widget.outlined) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }
    return widget.icon == null || _busy
        ? FilledButton(onPressed: onPressed, child: child)
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(widget.icon),
            label: child,
          );
  }
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
