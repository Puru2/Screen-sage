import 'package:flutter/material.dart';

abstract class ScreenSageColors {
  // ── Brand ──────────────────────────────────────────────────────
  static const accent = Color(0xFF00E5A0);
  static const accentDim = Color(0xFF00B87D);
  static const accentSurface = Color(0x1A00E5A0);

  static const violet = Color(0xFF7C6FFF);
  static const violetSurface = Color(0x1A7C6FFF);

  static const danger = Color(0xFFFF5757);
  static const dangerSurface = Color(0x1AFF5757);

  // ── NEW ────────────────────────────────────────────────────────
  static const amber = Color(0xFFFFB547); // ← add
  static const amberSurface = Color(0x1AFFB547); // ← add
  static const blue = Color(0xFF4DA6FF); // ← add
  static const blueSurface = Color(0x1A4DA6FF); // ← add

  // ── Backgrounds ────────────────────────────────────────────────
  static const background = Color(0xFF080C14);
  static const surface = Color(0xFF0F1520);
  static const surfaceHigh = Color(0xFF161D2E);
  static const border = Color(0xFF1E2A40);
  static const borderLight = Color(0xFF2A3A55);

  // ── Text ───────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8A9BB5);
  static const textTertiary = Color(0xFF4A5A73);

  // ── Semantic ───────────────────────────────────────────────────
  static const success = Color(0xFF00E5A0);
  static const warning = Color(0xFFFFB547);
  static const info = Color(0xFF4DA6FF);

  // ── Timer Arc ──────────────────────────────────────────────────
  static const timerGradientStart = Color(0xFF00E5A0);
  static const timerGradientEnd = Color(0xFF00A8FF);
}
