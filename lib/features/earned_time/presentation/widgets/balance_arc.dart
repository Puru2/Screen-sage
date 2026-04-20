import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class BalanceArc extends StatelessWidget {
  const BalanceArc({
    super.key,
    required this.balanceMins,
    required this.maxMins,
    this.isCountdown = false,
    this.overrideLabel,
  });

  final int balanceMins;
  final int maxMins;
  final bool isCountdown;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = (balanceMins / maxMins.clamp(1, maxMins)).clamp(0.0, 1.0);

    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(
        painter: _BalanceArcPainter(
          progress: ratio,
          isCountdown: isCountdown,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isCountdown) ...[
                const Text('💰', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  overrideLabel ?? '$balanceMins',
                  style: ScreenSageTextStyles.displayMedium.copyWith(
                    color: balanceMins > 0
                        ? ScreenSageColors.accent
                        : ScreenSageColors.textTertiary,
                  ),
                ),
                Text(
                  'minutes earned',
                  style: ScreenSageTextStyles.bodyMedium,
                ),
                if (balanceMins >= 180)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'MAX 🔥',
                      style: ScreenSageTextStyles.labelSmall.copyWith(
                        color: ScreenSageColors.amber,
                      ),
                    ),
                  ),
              ] else ...[
                const Text('⏳', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  overrideLabel ?? '$balanceMins',
                  style: ScreenSageTextStyles.timerDisplay.copyWith(
                    color: ScreenSageColors.accent,
                  ),
                ),
                Text(
                  'free time left',
                  style: ScreenSageTextStyles.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceArcPainter extends CustomPainter {
  const _BalanceArcPainter({
    required this.progress,
    required this.isCountdown,
  });
  final double progress;
  final bool isCountdown;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 10.0;
    const startAngle = -pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ScreenSageColors.border
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Progress with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      startAngle,
      2 * pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + (2 * pi * progress),
          colors: isCountdown
              ? [
                  ScreenSageColors.amber,
                  ScreenSageColors.accent,
                ]
              : [
                  ScreenSageColors.accent,
                  ScreenSageColors.violet,
                ],
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Tip dot
    final tipAngle = startAngle + (2 * pi * progress);
    canvas.drawCircle(
      Offset(
        center.dx + radius * cos(tipAngle),
        center.dy + radius * sin(tipAngle),
      ),
      6,
      Paint()
        ..color = isCountdown ? ScreenSageColors.amber : ScreenSageColors.violet
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BalanceArcPainter old) =>
      old.progress != progress || old.isCountdown != isCountdown;
}
