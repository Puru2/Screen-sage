import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../bloc/session_bloc.dart';

class DurationPicker extends StatefulWidget {
  const DurationPicker({
    super.key,
    required this.selectedDuration,
    required this.onDurationChanged,
  });

  final int selectedDuration;
  final ValueChanged<int> onDurationChanged;

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  final _durations = [5, 10, 15, 25, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child:
              Text('Session Duration', style: ScreenSageTextStyles.labelMedium),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _durations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final dur = _durations[index];
              final isSelected = dur == widget.selectedDuration;
              return GestureDetector(
                onTap: () => widget.onDurationChanged(dur),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ScreenSageColors.accent
                        : ScreenSageColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? ScreenSageColors.accent
                          : ScreenSageColors.border,
                    ),
                  ),
                  child: Text(
                    '${dur}m',
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? const Color(0xFF001A0F)
                          : ScreenSageColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
