import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/models/user_settings.dart';

class FocusModeSelector extends StatelessWidget {
  const FocusModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final FocusMode selectedMode;
  final ValueChanged<FocusMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: FocusMode.all.map((mode) {
          final isSelected = mode.type == selectedMode.type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ScreenSageColors.accentSurface
                      : ScreenSageColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? ScreenSageColors.accent.withOpacity(0.5)
                        : ScreenSageColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(mode.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      mode.label,
                      style: ScreenSageTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? ScreenSageColors.accent
                            : ScreenSageColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
