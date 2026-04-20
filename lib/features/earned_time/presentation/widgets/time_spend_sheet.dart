import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../bloc/earned_time_bloc.dart';

class SpendTimeSheet extends StatefulWidget {
  const SpendTimeSheet({super.key, required this.balanceMins});
  final int balanceMins;

  @override
  State<SpendTimeSheet> createState() => _SpendTimeSheetState();
}

class _SpendTimeSheetState extends State<SpendTimeSheet> {
  int _selected = 0;
  late final List<int> _options;

  @override
  void initState() {
    super.initState();
    // Only show options user can afford
    final all = [5, 10, 15, 20, 30, 45, 60];
    _options = all.where((m) => m <= widget.balanceMins).toList();
    if (_options.isNotEmpty) _selected = _options.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ScreenSageColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          Text('Spend Free Time', style: ScreenSageTextStyles.headlineMedium)
              .animate()
              .fadeIn(),

          const SizedBox(height: 4),

          Text(
            'Balance: ${widget.balanceMins}m  •  Max bank: 180m',
            style: ScreenSageTextStyles.bodySmall,
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 28),

          // Duration options grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _options.map((mins) {
              final isSelected = mins == _selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = mins);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ScreenSageColors.accent
                        : ScreenSageColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? ScreenSageColors.accent
                          : ScreenSageColors.border,
                    ),
                  ),
                  child: Text(
                    '${mins}m',
                    style: ScreenSageTextStyles.titleMedium.copyWith(
                      color: isSelected
                          ? const Color(0xFF001A0F)
                          : ScreenSageColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 28),

          // What you're unlocking
          if (_selected > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ScreenSageColors.accentSurface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🔓', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock blocked apps for $_selected minutes',
                          style: ScreenSageTextStyles.bodyLarge.copyWith(
                            color: ScreenSageColors.accent,
                          ),
                        ),
                        Text(
                          '${widget.balanceMins - _selected}m left in bank after',
                          style: ScreenSageTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 20),
          ],

          // Confirm button
          ElevatedButton.icon(
            onPressed: _selected == 0
                ? null
                : () {
                    Navigator.pop(context);
                    context.read<EarnedTimeBloc>().add(
                          EarnedTimeSpendRequested(_selected),
                        );
                  },
            icon: const Text('🎁', style: TextStyle(fontSize: 18)),
            label: Text('Unlock ${_selected}m of Free Time'),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}
