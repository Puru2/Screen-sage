import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';

class FocusBarChart extends StatelessWidget {
  const FocusBarChart({super.key, required this.dailyMins});
  final Map<String, int> dailyMins;

  @override
  Widget build(BuildContext context) {
    if (dailyMins.isEmpty) return const SizedBox(height: 140);

    final entries = dailyMins.entries.toList();
    final isMonthView = entries.length > 10; // week=7, month=28-31

    final maxMins = dailyMins.values.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxMins == 0 ? 60 : maxMins;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final isToday = _isToday(entry.key, isMonthView);
          final ratio = entry.value / effectiveMax;
          final barHeight = (ratio * 80).clamp(4.0, 80.0);
          final hasData = entry.value > 0;

          // Month view — only show label on 1st, 7th, 14th, 21st, 28th
          // Week view — show all 7 labels
          final showLabel = isMonthView ? (i == 0 || (i + 1) % 7 == 0) : true;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Value label — only on today or hovered (keep simple)
                if (hasData && (isToday || (!isMonthView)))
                  Text(
                    _formatMins(entry.value),
                    style: TextStyle(
                      fontSize: 9,
                      color: isToday
                          ? ScreenSageColors.accent
                          : ScreenSageColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const SizedBox(height: 14),

                const SizedBox(height: 4),

                // Bar
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 20),
                  curve: Curves.easeOutCubic,
                  height: barHeight,
                  margin: EdgeInsets.symmetric(
                    horizontal: isMonthView ? 1.5 : 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isMonthView ? 3 : 6),
                    color: isToday
                        ? ScreenSageColors.accent
                        : hasData
                            ? ScreenSageColors.accent.withOpacity(0.35)
                            : ScreenSageColors.border,
                  ),
                ),

                const SizedBox(height: 6),

                // Day label — conditionally shown
                SizedBox(
                  height: 14,
                  child: showLabel
                      ? Text(
                          // For month view show day number, week shows Mon/Tue etc
                          isMonthView ? '${i + 1}' : entry.key,
                          style: TextStyle(
                            fontSize: isMonthView ? 8 : 10,
                            color: isToday
                                ? ScreenSageColors.accent
                                : ScreenSageColors.textTertiary,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isToday(String label, bool isMonthView) {
    if (isMonthView) {
      // For month — check if this key matches today's day number
      final todayDay = DateTime.now().day.toString();
      return label == todayDay;
    }
    // For week — match day name
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1] == label;
  }

  String _formatMins(int mins) {
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h';
  }
}
