import 'package:flutter/material.dart';
import 'color_scheme.dart';

abstract class ScreenSageTextStyles {
  // Uses system font (SF Pro on iOS, Roboto on Android)
  // Adding a custom font later = change fontFamily here only

  static const displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.1,
  );

  static const displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.15,
  );

  static const headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ScreenSageColors.textPrimary,
    height: 1.6,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ScreenSageColors.textSecondary,
    height: 1.55,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: ScreenSageColors.textTertiary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ScreenSageColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: ScreenSageColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: ScreenSageColors.textTertiary,
    letterSpacing: 0.5,
  );

  // ── Accent variants ─────────────────────────────────────────────
  static const accentLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: ScreenSageColors.accent,
    letterSpacing: 0.3,
  );

  static const timerDisplay = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w300,
    color: ScreenSageColors.textPrimary,
    letterSpacing: -3,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
