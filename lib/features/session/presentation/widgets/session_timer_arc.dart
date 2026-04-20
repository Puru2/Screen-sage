import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class SessionTimerArc extends StatelessWidget {
  const SessionTimerArc({
    super.key,
    required this.progress,
    required this.remainingMinutes,
    required this.remainingSeconds,
    required this.isIdle,
    required this.durationMinutes,
  });

  final double progress;
  final int remainingMinutes;
  final int remainingSeconds;
  final bool isIdle;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress, isIdle: isIdle),
        child: Center(
          child: isIdle
              ? _IdleCenter(durationMinutes: durationMinutes)
              : _ActiveCenter(
                  minutes: remainingMinutes,
                  seconds: remainingSeconds,
                ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.isIdle});
  final double progress;
  final bool isIdle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 10.0;
    const startAngle = -pi / 2; // Start at top

    // Background track
    final trackPaint = Paint()
      ..color = ScreenSageColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (!isIdle && progress > 0) {
      // Progress arc with gradient
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradientPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + (2 * pi * progress),
          colors: const [
            ScreenSageColors.timerGradientStart,
            ScreenSageColors.timerGradientEnd,
          ],
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        2 * pi * progress,
        false,
        gradientPaint,
      );

      // Dot at the progress tip
      final dotAngle = startAngle + (2 * pi * progress);
      final dotX = center.dx + radius * cos(dotAngle);
      final dotY = center.dy + radius * sin(dotAngle);

      final dotPaint = Paint()
        ..color = ScreenSageColors.timerGradientEnd
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isIdle != isIdle;
}

class _IdleCenter extends StatelessWidget {
  const _IdleCenter({required this.durationMinutes});
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.forest_rounded,
          color: ScreenSageColors.accent,
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          '$durationMinutes',
          style: ScreenSageTextStyles.displayMedium.copyWith(
            color: ScreenSageColors.textPrimary,
          ),
        ),
        Text(
          'minutes',
          style: ScreenSageTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _ActiveCenter extends StatelessWidget {
  const _ActiveCenter({required this.minutes, required this.seconds});
  final int minutes;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: ScreenSageTextStyles.timerDisplay,
        ),
        Text(
          'remaining',
          style: ScreenSageTextStyles.bodyMedium,
        ),
      ],
    );
  }
}
