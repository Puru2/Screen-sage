import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

// ── SharedPrefs key ───────────────────────────────────────────────
const _kOnboardingSeen = 'philosophy_onboarding_seen';

class PhilosophyOnboarding extends StatefulWidget {
  /// [isFromSettings] = true → shown from Settings "Our Philosophy" row
  /// [isFromSettings] = false → shown at first launch before login
  const PhilosophyOnboarding({
    super.key,
    this.isFromSettings = false,
    this.onDone,
  });

  final bool isFromSettings;
  final VoidCallback? onDone;

  /// Check if onboarding has been seen before.
  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingSeen) ?? false;
  }

  /// Mark as seen.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeen, true);
  }

  @override
  State<PhilosophyOnboarding> createState() => _PhilosophyOnboardingState();
}

class _PhilosophyOnboardingState extends State<PhilosophyOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.psychology_outlined,
      tag: 'The Problem',
      headline: 'Your phone is\ndesigned to win.',
      body:
          'Every notification, every feed, every autoplay — engineered by teams of PhDs to keep you scrolling. You were never meant to win this fight alone.',
      stat: '23 minutes',
      statLabel: 'to regain focus after a single interruption',
      statSource: 'UC Irvine, 2023',
    ),
    _OnboardingPage(
      icon: Icons.lock_outline_rounded,
      tag: 'Why Blocking Fails',
      headline: 'Forced focus\ndoesn\'t stick.',
      body:
          'Apps that lock your phone like a parent teach your brain nothing. The moment the lock lifts, old habits snap back. Control without understanding creates dependency, not discipline.',
      stat: '0 habits built',
      statLabel: 'by removing choice — autonomy is required for lasting change',
      statSource: 'Ryan & Deci, Self-Determination Theory, 2017',
    ),
    _OnboardingPage(
      icon: Icons.track_changes_outlined,
      tag: 'The Science',
      headline: 'Intentional focus\nbuilds real habits.',
      body:
          'When you choose to focus — and feel the cost of breaking that choice — your brain builds genuine self-regulation. Autonomy-supportive environments create habits that outlast the app.',
      stat: '121%',
      statLabel: 'higher engagement with protected, self-chosen focus time',
      statSource: 'Microsoft Viva Insights, 2024',
    ),
    _OnboardingPage(
      icon: Icons.auto_graph_outlined,
      tag: 'Our Approach',
      headline: 'We make the cost\nof distraction visible.',
      body:
          'ScreenSage doesn\'t fight your phone for you. It shows you the real price of every override — your streak, your DNA, your data — until you don\'t need us to remind you anymore.',
      stat: 'Your streak',
      statLabel: 'is the consequence. Your DNA is the reward. You choose both.',
      statSource: null,
    ),
    _OnboardingPage(
      icon: Icons.diamond_outlined,
      tag: 'What You Get',
      headline: 'Focus that means\nsomething.',
      body:
          'Every session you complete builds your Focus DNA — a living record of who you\'re becoming. Not a streak for its own sake. Proof that you showed up, consistently, on purpose.',
      stat: null,
      statLabel: null,
      statSource: null,
      isLast: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _finish();
  }

  Future<void> _finish() async {
    if (!widget.isFromSettings) {
      await PhilosophyOnboarding.markSeen();
    }
    if (mounted) {
      widget.onDone?.call();
      if (widget.isFromSettings) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ScreenSage wordmark
                  Text(
                    'ScreenSage',
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: ScreenSageColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Skip — hidden on last page
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Skip',
                        style: ScreenSageTextStyles.bodySmall.copyWith(
                          color: ScreenSageColors.textTertiary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Progress dots ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? ScreenSageColors.accent
                          : ScreenSageColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

            // ── Pages ─────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = i);
                },
                itemCount: _pages.length,
                itemBuilder: (context, i) => _PageContent(page: _pages[i]),
              ),
            ),

            // ── CTA ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _next,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ScreenSageColors.accent,
                            ScreenSageColors.violet,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: ScreenSageColors.accent.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'Continue'
                              : widget.isFromSettings
                                  ? 'Got it'
                                  : 'Start My Journey',
                          style: ScreenSageTextStyles.titleMedium.copyWith(
                            color: const Color(0xFF001A0F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  // Page indicator text
                  const SizedBox(height: 12),
                  Text(
                    '${_currentPage + 1} of ${_pages.length}',
                    style: ScreenSageTextStyles.bodySmall.copyWith(
                      color: ScreenSageColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Content ──────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});
  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in a glowing container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ScreenSageColors.accentSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: ScreenSageColors.accent.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: ScreenSageColors.accent.withOpacity(0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                page.icon,
                color: ScreenSageColors.accent,
                size: 32,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.85, 0.85)),

            const SizedBox(height: 24),

            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ScreenSageColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ScreenSageColors.border),
              ),
              child: Text(
                page.tag.toUpperCase(),
                style: ScreenSageTextStyles.labelSmall.copyWith(
                  color: ScreenSageColors.textTertiary,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 14),

            // Headline
            Text(
              page.headline,
              style: ScreenSageTextStyles.displayMedium.copyWith(
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06),

            const SizedBox(height: 16),

            // Body
            Text(
              page.body,
              style: ScreenSageTextStyles.bodyLarge.copyWith(
                color: ScreenSageColors.textSecondary,
                height: 1.65,
              ),
            ).animate().fadeIn(delay: 200.ms),

            // Stat card — only if stat exists
            if (page.stat != null) ...[
              const SizedBox(height: 28),
              _StatCard(
                stat: page.stat!,
                label: page.statLabel!,
                source: page.statSource,
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.08),
            ],

            // Last page feature grid
            if (page.isLast) ...[
              const SizedBox(height: 28),
              _FeatureGrid().animate().fadeIn(delay: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.stat,
    required this.label,
    this.source,
  });

  final String stat;
  final String label;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stat,
                style: ScreenSageTextStyles.headlineLarge.copyWith(
                  color: ScreenSageColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: ScreenSageTextStyles.bodySmall.copyWith(
              color: ScreenSageColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (source != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 11,
                  color: ScreenSageColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  source!,
                  style: ScreenSageTextStyles.bodySmall.copyWith(
                    color: ScreenSageColors.textTertiary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Feature Grid — last page ──────────────────────────────────────
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _items = [
    (Icons.biotech_outlined, 'Focus DNA'),
    (Icons.auto_awesome_outlined, 'Constellation'),
    (Icons.bar_chart_outlined, 'Deep Analytics'),
    (Icons.shield_outlined, 'Focus Shield'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: _items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ScreenSageColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ScreenSageColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    item.$1,
                    color: ScreenSageColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: ScreenSageTextStyles.labelSmall.copyWith(
                        color: ScreenSageColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.tag,
    required this.headline,
    required this.body,
    this.stat,
    this.statLabel,
    this.statSource,
    this.isLast = false,
  });

  final IconData icon;
  final String tag;
  final String headline;
  final String body;
  final String? stat;
  final String? statLabel;
  final String? statSource;
  final bool isLast;
}
