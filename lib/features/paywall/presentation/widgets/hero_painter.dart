import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/color_scheme.dart';

class HeroStarPainter extends CustomPainter {
  const HeroStarPainter({required this.twinkle});
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    const stars = [
      (0.15, 0.3, 6.0),
      (0.35, 0.15, 4.5),
      (0.55, 0.45, 7.0),
      (0.70, 0.2, 5.0),
      (0.85, 0.5, 5.5),
      (0.45, 0.75, 4.0),
      (0.22, 0.65, 3.5),
    ];
    const connections = [
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (2, 5),
      (5, 6),
      (6, 0),
    ];

    final positions = stars
        .map((s) => Offset(s.$1 * size.width, s.$2 * size.height))
        .toList();

    // Lines
    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (final c in connections) {
      linePaint.color = ScreenSageColors.accent.withOpacity(0.2);
      canvas.drawLine(positions[c.$1], positions[c.$2], linePaint);
    }

    // Stars
    for (int i = 0; i < stars.length; i++) {
      final s = stars[i];
      final pos = positions[i];
      final phase = (i * 0.618) % 1.0;
      final t = 0.85 + 0.15 * sin((twinkle + phase) * 2 * pi);
      final r = s.$3 * t;

      // Glow
      canvas.drawCircle(
        pos,
        r * 2.2,
        Paint()
          ..color = ScreenSageColors.accent.withOpacity(0.15 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Star shape
      _drawStar(canvas, pos, r,
          Paint()..color = ScreenSageColors.accent.withOpacity(0.9 * t));

      // White center
      canvas.drawCircle(
          pos, r * 0.3, Paint()..color = Colors.white.withOpacity(0.7 * t));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    final inner = r * 0.42;
    for (int i = 0; i < 10; i++) {
      final angle = (i * pi / 5) - pi / 2;
      final radius = i.isEven ? r : inner;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HeroStarPainter old) => old.twinkle != twinkle;
}
