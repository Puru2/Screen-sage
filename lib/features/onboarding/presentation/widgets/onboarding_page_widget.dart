import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/onboarding_data.dart';

class OnboardingPageWidget extends StatelessWidget {
  const OnboardingPageWidget({super.key, required this.data});
  final OnboardingPage data;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),

            // Emoji with glow
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: ScreenSageColors.accentSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: ScreenSageColors.accent.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(data.emoji, style: const TextStyle(fontSize: 44)),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8)),

            const SizedBox(height: 40),

            // Headline — most important, biggest
            Text(data.headline, style: ScreenSageTextStyles.displayMedium)
                .animate()
                .fadeIn(delay: 150.ms, duration: 500.ms)
                .slideX(begin: -0.05),

            const SizedBox(height: 16),

            // Subheadline in accent color
            Text(
              data.subheadline,
              style: ScreenSageTextStyles.titleMedium.copyWith(
                color: ScreenSageColors.accent,
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

            const SizedBox(height: 16),

            // Body
            Text(data.body,
                style: ScreenSageTextStyles.bodyLarge.copyWith(
                  color: ScreenSageColors.textSecondary,
                )).animate().fadeIn(delay: 350.ms, duration: 400.ms),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
