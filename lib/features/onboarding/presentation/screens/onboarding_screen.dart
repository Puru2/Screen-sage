import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/services/screen_time_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0;
  bool _authGranted = false;
  bool _requesting = false;

  late AnimationController _bgPulse;

  static const _total = 5;

  @override
  void initState() {
    super.initState();
    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: Stack(
        children: [
          // Ambient background — shifts per page
          AnimatedBuilder(
            animation: _bgPulse,
            builder: (_, __) => _AmbientBackground(
              page: _page,
              pulse: _bgPulse.value,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button (hidden on page 0)
                      AnimatedOpacity(
                        opacity: _page > 0 ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          onPressed: _page > 0 ? _back : null,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: ScreenSageColors.textTertiary),
                        ),
                      ),

                      // Page dots
                      Row(
                        children: List.generate(_total, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? ScreenSageColors.accent
                                  : ScreenSageColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      // Skip
                      _page < _total - 1
                          ? TextButton(
                              onPressed: _skipToLast,
                              child: Text(
                                'Skip',
                                style: ScreenSageTextStyles.bodySmall.copyWith(
                                    color: ScreenSageColors.textTertiary),
                              ),
                            )
                          : const SizedBox(width: 64),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _page = i);
                    },
                    children: [
                      _PageOne(),
                      _PageTwo(),
                      _PageThree(),
                      _PageFour(),
                      _PageFive(
                        authGranted: _authGranted,
                        requesting: _requesting,
                        onRequest: _requestPermission,
                      ),
                    ],
                  ),
                ),

                // CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCta(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    // Pages 0–3 — Next
    if (_page < _total - 1) {
      return _GlowButton(
        key: ValueKey('next_$_page'),
        label: 'Continue',
        onTap: _next,
      );
    }

    // Last page — permission not yet granted
    if (!_authGranted) {
      return _GlowButton(
        key: const ValueKey('permission'),
        label: _requesting ? 'Requesting...' : 'Grant Screen Time Access',
        loading: _requesting,
        onTap: _requesting ? null : _requestPermission,
        secondary: true,
      );
    }

    // Permission granted — go
    return _GlowButton(
      key: const ValueKey('launch'),
      label: "I'm ready",
      onTap: _finish,
      showArrow: true,
    );
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _skipToLast() {
    _pageController.animateToPage(
      _total - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    HapticFeedback.mediumImpact();
    final granted = await ScreenTimeService.requestAuthorization();
    if (mounted) {
      setState(() {
        _authGranted = granted;
        _requesting = false;
      });
      if (granted) {
        HapticFeedback.heavyImpact();
        // Ask notification permission right after — user is already saying yes
        await NotificationService.requestPermission();
        // Schedule default 9am daily reminder
        final name =
            FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ??
                'there';
        await NotificationService.scheduleDailyReminder(
          hour: 9,
          minute: 0,
          name: name,
        );
        await NotificationService.scheduleStreakRisk(name: name);
      }
    }
  }

  Future<void> _finish() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go('/auth');
  }
}

// ── Page 1 — The hook ─────────────────────────────────────────────
// "Your phone is winning."
class _PageOne extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            '96',
            style: TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.w800,
              color: ScreenSageColors.accent,
              height: 1,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
          Text(
            'times a day\nyou unlock\nyour phone.',
            style: ScreenSageTextStyles.displayMedium.copyWith(
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 20),
          Text(
            'Most of them are habits, not choices.',
            style: ScreenSageTextStyles.bodyLarge.copyWith(
              color: ScreenSageColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Page 2 — The difference ───────────────────────────────────────
// "We don't block. We trade."
class _PageTwo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),

          Text(
            'Other apps\npunish you.',
            style: ScreenSageTextStyles.displayMedium.copyWith(
              color: ScreenSageColors.textSecondary,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // The contrast line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ScreenSageColors.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
            ),
            child: Text(
              'ScreenSage rewards you.',
              style: ScreenSageTextStyles.bodySmall.copyWith(
                color: ScreenSageColors.accent,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideX(begin: -0.05),

          const SizedBox(height: 24),

          Text(
            'Every minute you focus = 1 minute of\nguilt-free phone time. Earned, not stolen.',
            style: ScreenSageTextStyles.bodyLarge.copyWith(
              color: ScreenSageColors.textSecondary,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Page 3 — Focus DNA ────────────────────────────────────────────
// "You're not just building habits. You're building an identity."
class _PageThree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            '🧬',
            style: const TextStyle(fontSize: 64),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                duration: 700.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(),
          const SizedBox(height: 28),
          Text(
            'The longer\nyou use it,\nthe more it\nknows you.',
            style: ScreenSageTextStyles.displayMedium.copyWith(
              height: 1.15,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 20),
          Text(
            'Focus DNA builds your unique focus profile — when you work best, how long you last, what breaks you.',
            style: ScreenSageTextStyles.bodyLarge.copyWith(
              color: ScreenSageColors.textSecondary,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Page 4 — Constellation ────────────────────────────────────────
// "Your focus has a shape."
class _PageFour extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),

          // Mini constellation preview — static decorative stars
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _MiniStarPainter(),
            ),
          ).animate().fadeIn(duration: 800.ms),

          const SizedBox(height: 28),

          Text(
            'Your focus\nhas a shape.',
            style: ScreenSageTextStyles.displayMedium.copyWith(
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.1),

          const SizedBox(height: 20),

          Text(
            'Every session you complete becomes a star in your personal constellation. Watch your sky fill up.',
            style: ScreenSageTextStyles.bodyLarge.copyWith(
              color: ScreenSageColors.textSecondary,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Page 5 — Permission ───────────────────────────────────────────
// "One permission. That's all."
class _PageFive extends StatelessWidget {
  const _PageFive({
    required this.authGranted,
    required this.requesting,
    required this.onRequest,
  });

  final bool authGranted;
  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: authGranted
                ? Text(
                    '✅',
                    key: const ValueKey('check'),
                    style: const TextStyle(fontSize: 64),
                  ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    )
                : Text(
                    '🛡️',
                    key: const ValueKey('shield'),
                    style: const TextStyle(fontSize: 64),
                  ).animate().fadeIn(),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: authGranted
                ? Text(
                    "You're all\nset.",
                    key: const ValueKey('granted'),
                    style: ScreenSageTextStyles.displayMedium.copyWith(
                      color: ScreenSageColors.accent,
                      height: 1.2,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1)
                : Text(
                    'One permission\nneeded.',
                    key: const ValueKey('needed'),
                    style: ScreenSageTextStyles.displayMedium
                        .copyWith(height: 1.2),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: authGranted
                ? Text(
                    "Screen Time access granted. ScreenSage can now protect your focus sessions.",
                    key: const ValueKey('body_granted'),
                    style: ScreenSageTextStyles.bodyLarge.copyWith(
                      color: ScreenSageColors.textSecondary,
                      height: 1.6,
                    ),
                  ).animate().fadeIn()
                : Text(
                    'ScreenSage uses Screen Time to block distracting apps during your sessions.\n\nWe never read your data. We never sell it.',
                    key: const ValueKey('body_needed'),
                    style: ScreenSageTextStyles.bodyLarge.copyWith(
                      color: ScreenSageColors.textSecondary,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Ambient Background ────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({
    required this.page,
    required this.pulse,
  });

  final int page;
  final double pulse;

  // Each page has a different ambient color
  static const _colors = [
    ScreenSageColors.danger, // page 0 — red/urgency (96 unlocks)
    ScreenSageColors.accent, // page 1 — green/reward
    ScreenSageColors.violet, // page 2 — violet/identity
    Color(0xFF4A90E2), // page 3 — blue/constellation
    ScreenSageColors.accent, // page 4 — green/ready
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[page.clamp(0, _colors.length - 1)];
    final opacity = 0.05 + 0.03 * pulse;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.7),
          radius: 1.2,
          colors: [
            color.withOpacity(opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Glow Button ───────────────────────────────────────────────────
class _GlowButton extends StatelessWidget {
  const _GlowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.secondary = false,
    this.showArrow = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool secondary;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          gradient: secondary || loading
              ? null
              : const LinearGradient(
                  colors: [
                    ScreenSageColors.accent,
                    ScreenSageColors.violet,
                  ],
                ),
          color: secondary || loading ? ScreenSageColors.surface : null,
          borderRadius: BorderRadius.circular(18),
          border: secondary ? Border.all(color: ScreenSageColors.border) : null,
          boxShadow: secondary || loading
              ? null
              : [
                  BoxShadow(
                    color: ScreenSageColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ScreenSageColors.accent,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: ScreenSageTextStyles.titleMedium.copyWith(
                        color: secondary
                            ? ScreenSageColors.textSecondary
                            : const Color(0xFF001A0F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: secondary
                            ? ScreenSageColors.textSecondary
                            : const Color(0xFF001A0F),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    ).animate(key: key).fadeIn(duration: 300.ms).slideY(begin: 0.06);
  }
}

// ── Page Shell ────────────────────────────────────────────────────
class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: child,
    );
  }
}

// ── Mini Star Painter (Page 4 decoration) ─────────────────────────
class _MiniStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final paint = Paint()..style = PaintingStyle.fill;

    // Fixed decorative stars suggesting a constellation
    const stars = [
      (0.1, 0.3, 4.0, 0.9),
      (0.25, 0.15, 3.0, 0.7),
      (0.4, 0.5, 5.0, 1.0),
      (0.55, 0.2, 3.5, 0.8),
      (0.65, 0.6, 4.0, 0.9),
      (0.78, 0.35, 3.0, 0.7),
      (0.88, 0.55, 4.5, 1.0),
      (0.15, 0.7, 2.5, 0.6),
      (0.5, 0.8, 3.0, 0.7),
    ];

    // Connection lines
    final linePaint = Paint()
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke
      ..color = ScreenSageColors.accent.withOpacity(0.2);

    final positions = stars
        .map((s) => Offset(s.$1 * size.width, s.$2 * size.height))
        .toList();

    // Connect nearby stars
    const connections = [
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (5, 6),
      (2, 7),
      (7, 8)
    ];
    for (final c in connections) {
      canvas.drawLine(positions[c.$1], positions[c.$2], linePaint);
    }

    // Stars
    for (int i = 0; i < stars.length; i++) {
      final s = stars[i];
      final pos = positions[i];
      // Glow
      canvas.drawCircle(
        pos,
        s.$3 * 2,
        Paint()
          ..color = ScreenSageColors.accent.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Star
      paint.color = ScreenSageColors.accent.withOpacity(s.$4);
      canvas.drawCircle(pos, s.$3, paint);
      // White center
      canvas.drawCircle(
          pos, s.$3 * 0.35, Paint()..color = Colors.white.withOpacity(0.6));
    }

    // Background dust
    for (int i = 0; i < 25; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 0.8,
        Paint()..color = Colors.white.withOpacity(rng.nextDouble() * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
