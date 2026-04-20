import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class SessionHistoryTile extends StatelessWidget {
  const SessionHistoryTile({
    super.key,
    required this.durationMins,
    required this.completedMins,
    required this.overrides,
    required this.completed,
    required this.startedAt,
  });

  final int durationMins;
  final int completedMins;
  final int overrides;
  final bool completed;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completed
                ? ScreenSageColors.accent.withOpacity(0.2)
                : ScreenSageColors.border,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: completed
                    ? ScreenSageColors.accentSurface
                    : ScreenSageColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  completed ? '✅' : '⚡',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        completed
                            ? '${completedMins}m session'
                            : '${completedMins}m of ${durationMins}m',
                        style: ScreenSageTextStyles.bodyLarge,
                      ),
                      if (!completed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ScreenSageColors.dangerSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'incomplete',
                            style: ScreenSageTextStyles.labelSmall.copyWith(
                              color: ScreenSageColors.danger,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(startedAt),
                    style: ScreenSageTextStyles.bodySmall,
                  ),
                ],
              ),
            ),

            // Override count
            if (overrides > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ScreenSageColors.dangerSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$overrides override${overrides > 1 ? 's' : ''}',
                  style: ScreenSageTextStyles.labelSmall.copyWith(
                    color: ScreenSageColors.danger,
                  ),
                ),
              )
            else if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ScreenSageColors.accentSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'clean 🌿',
                  style: ScreenSageTextStyles.labelSmall.copyWith(
                    color: ScreenSageColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(sessionDay).inDays;

    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today at $time';
    if (diff == 1) return 'Yesterday at $time';
    return '${dt.day}/${dt.month} at $time';
  }
}
