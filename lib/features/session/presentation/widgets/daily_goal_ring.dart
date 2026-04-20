import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({
    super.key,
    required this.todayMins,
    required this.goalMins,
  });

  final int todayMins;
  final int goalMins;

  @override
  Widget build(BuildContext context) {
    final progress =
        goalMins > 0 ? (todayMins / goalMins).clamp(0.0, 1.0) : 0.0;
    final isComplete = todayMins >= goalMins;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? ScreenSageColors.accent.withOpacity(0.4)
                : ScreenSageColors.border,
          ),
        ),
        child: Row(
          children: [
            // Mini arc ring
            SizedBox(
              width: 48,
              height: 48,
              child: CustomPaint(
                painter: _MiniRingPainter(progress: progress),
                child: Center(
                  child: Text(
                    isComplete ? '✅' : '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: isComplete ? 18 : 10,
                      fontWeight: FontWeight.w700,
                      color: isComplete ? null : ScreenSageColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete ? 'Daily goal reached! 🎉' : 'Daily Goal',
                    style: ScreenSageTextStyles.bodyLarge.copyWith(
                      color: isComplete
                          ? ScreenSageColors.accent
                          : ScreenSageColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmt(todayMins)} of ${_fmt(goalMins)} focused today',
                    style: ScreenSageTextStyles.bodySmall,
                  ),
                ],
              ),
            ),

            // Progress bar
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: ScreenSageColors.border,
                  valueColor: AlwaysStoppedAnimation(
                    isComplete
                        ? ScreenSageColors.accent
                        : ScreenSageColors.violet,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _MiniRingPainter extends CustomPainter {
  const _MiniRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ScreenSageColors.border
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color =
            progress >= 1.0 ? ScreenSageColors.accent : ScreenSageColors.violet
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}
