import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/config/timings.dart';
import '../../../application/services/emission_service.dart';
import '../../strings.dart';
import '../../theme/app_text_styles.dart';

/// VU-mètre analogique « NIVEAU D'ÉMISSION » (BRIEF §8.1.a). Géométrie exacte du
/// prototype (viewBox 300×96, pivot 150,86, `angle = v*10−50`, repos −46°).
class VuMeter extends ConsumerWidget {
  const VuMeter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(emissionServiceProvider.select((s) => s.level));
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF0A0A07), width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4EED9), Color(0xFFDCD0AD)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 300 / 96,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: level.angleDegrees),
              duration: Timings.vuTransition,
              builder: (context, angle, _) =>
                  CustomPaint(painter: _VuPainter(angle)),
            ),
          ),
          Positioned(
            left: 9,
            top: 6,
            child: Text(
              Strings.vuLabel,
              style: AppText.body(
                size: 9,
                weight: FontWeight.w700,
                color: const Color(0xFF5B4A22),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VuPainter extends CustomPainter {
  _VuPainter(this.angle);

  /// Angle courant de l'aiguille, en degrés.
  final double angle;

  static Offset _pt(double r, double aDeg) {
    final t = aDeg * math.pi / 180;
    return Offset(150 + r * math.sin(t), 86 - r * math.cos(t));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);

    // Graduations 0..10.
    final tick = Paint();
    for (var v = 0; v <= 10; v++) {
      final a = v * 10 - 50.0;
      final major = v.isEven;
      final hot = v >= 8;
      tick
        ..color = hot
            ? const Color(0xFFA3271A)
            : (major ? const Color(0xFF13110B) : const Color(0xFF2B261A))
        ..strokeWidth = major ? 2 : 1;
      canvas.drawLine(_pt(68, a), _pt(major ? 52 : 60, a), tick);
    }

    // Chiffres 0 · 5 · 10.
    for (final (v, label) in const [(0.0, '0'), (5.0, '5'), (10.0, '10')]) {
      final p = _pt(42, v * 10 - 50);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: v >= 8 ? const Color(0xFFA3271A) : const Color(0xFF1C180F),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2 + 2));
    }

    // Zone rouge (v ≥ 8) : arc rayon 64, angles aiguille 30°→50°.
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(150, 86), radius: 64),
      -60 * math.pi / 180,
      20 * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB3331E).withValues(alpha: 0.85),
    );

    // Aiguille.
    canvas.drawLine(
      const Offset(150, 86),
      _pt(64, angle),
      Paint()
        ..color = const Color(0xFF7A1A0C)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Pivot.
    canvas.drawCircle(
      const Offset(150, 86),
      6,
      Paint()..color = const Color(0xFF1C1C18),
    );
    canvas.drawCircle(
      const Offset(150, 86),
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF000000),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VuPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
