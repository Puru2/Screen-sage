import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'color_scheme.dart';
import 'text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ScreenSageColors.background,

      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: ScreenSageColors.accent,
        onPrimary: Color(0xFF001A0F),
        secondary: ScreenSageColors.violet,
        onSecondary: Color(0xFF0D0A2E),
        error: ScreenSageColors.danger,
        surface: ScreenSageColors.surface,
        onSurface: ScreenSageColors.textPrimary,
        outline: ScreenSageColors.border,
        outlineVariant: ScreenSageColors.borderLight,
      ),

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: ScreenSageTextStyles.titleLarge,
        iconTheme: IconThemeData(color: ScreenSageColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: ScreenSageColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ScreenSageColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom Navigation ────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ScreenSageColors.surface,
        indicatorColor: ScreenSageColors.accentSurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ScreenSageTextStyles.labelSmall.copyWith(
              color: ScreenSageColors.accent,
              fontWeight: FontWeight.w600,
            );
          }
          return ScreenSageTextStyles.labelSmall;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: ScreenSageColors.accent, size: 22);
          }
          return const IconThemeData(
              color: ScreenSageColors.textTertiary, size: 22);
        }),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── Input Fields ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ScreenSageColors.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ScreenSageColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ScreenSageColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: ScreenSageColors.accent, width: 1.5),
        ),
        hintStyle: ScreenSageTextStyles.bodyMedium,
        labelStyle: ScreenSageTextStyles.bodyMedium,
      ),

      // ── Elevated Buttons ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ScreenSageColors.accent,
          foregroundColor: const Color(0xFF001A0F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: ScreenSageTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
      ),

      // ── Text Buttons ────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ScreenSageColors.accent,
          textStyle: ScreenSageTextStyles.labelMedium.copyWith(
            color: ScreenSageColors.accent,
          ),
        ),
      ),

      // ── Outlined Buttons ────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ScreenSageColors.textPrimary,
          side: const BorderSide(color: ScreenSageColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 54),
          textStyle: ScreenSageTextStyles.labelLarge,
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: ScreenSageColors.surfaceHigh,
        selectedColor: ScreenSageColors.accentSurface,
        side: const BorderSide(color: ScreenSageColors.border),
        labelStyle: ScreenSageTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: ScreenSageColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Sheet ────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ScreenSageColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: ScreenSageColors.borderLight,
        dragHandleSize: Size(40, 4),
      ),

      // ── Text Theme ──────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: ScreenSageTextStyles.displayLarge,
        displayMedium: ScreenSageTextStyles.displayMedium,
        headlineLarge: ScreenSageTextStyles.headlineLarge,
        headlineMedium: ScreenSageTextStyles.headlineMedium,
        titleLarge: ScreenSageTextStyles.titleLarge,
        titleMedium: ScreenSageTextStyles.titleMedium,
        bodyLarge: ScreenSageTextStyles.bodyLarge,
        bodyMedium: ScreenSageTextStyles.bodyMedium,
        bodySmall: ScreenSageTextStyles.bodySmall,
        labelLarge: ScreenSageTextStyles.labelLarge,
        labelMedium: ScreenSageTextStyles.labelMedium,
        labelSmall: ScreenSageTextStyles.labelSmall,
      ),

      // ── Page Transitions ────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
