import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/revenue_cat_service.dart';
import 'widgets/hero_painter.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.onSuccess});
  final Future<void> Function()? onSuccess;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  List<Package> _packages = [];
  Package? _selected;
  bool _loadingPackages = true;
  bool _purchasing = false;
  bool _restoring = false;
  late AnimationController _bgPulse;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _loadPackages();
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    final packages = await RevenueCatService.getPackages();
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _loadingPackages = false;

      if (packages.isEmpty) {
        _selected = null; // ← safe, handled in UI below
        return;
      }

      // Default to annual, fall back to first available — no null bang
      _selected = packages.firstWhere(
        (p) => p.packageType == PackageType.annual,
        orElse: () => packages.first, // ← removed _selected! bang
      );
    });
  }

  Future<void> _purchase() async {
    if (_selected == null || _purchasing) return;
    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);

    try {
      final success = await RevenueCatService.purchase(_selected!);
      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        await widget.onSuccess?.call(); // ← now properly awaitable
        if (!mounted) return;
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } on PurchasesErrorCode catch (e) {
      if (!mounted) return;
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        _showError('Purchase failed. Please try again.');
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    HapticFeedback.lightImpact();
    setState(() => _restoring = true);
    try {
      final success = await RevenueCatService.restore();
      if (!mounted) return;
      if (success) {
        HapticFeedback.heavyImpact();
        await widget.onSuccess?.call(); // ← properly awaitable
        if (!mounted) return;
        setState(() => _showSuccess = true);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _showError('No previous purchases found.');
      }
    } catch (e) {
      if (mounted) _showError('Restore failed. Please try again.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ScreenSageColors.dangerSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: Stack(
        children: [
          // ── Ambient background ────────────────────────────
          AnimatedBuilder(
            animation: _bgPulse,
            builder: (_, __) => Stack(
              children: [
                // Top-left glow
                Positioned(
                  top: -120,
                  left: -80,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          ScreenSageColors.accent
                              .withOpacity(0.08 + 0.04 * _bgPulse.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom-right glow
                Positioned(
                  bottom: -80,
                  right: -60,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          ScreenSageColors.violet
                              .withOpacity(0.07 + 0.03 * _bgPulse.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ScreenSageColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: ScreenSageColors.border),
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: ScreenSageColors.textSecondary),
                        ),
                      ),

                      // Trial badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ScreenSageColors.accentSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ScreenSageColors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '7 days free',
                          style: ScreenSageTextStyles.labelSmall.copyWith(
                            color: ScreenSageColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Restore
                      TextButton(
                        onPressed: _restoring ? null : _restore,
                        child: _restoring
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: ScreenSageColors.textTertiary,
                                ),
                              )
                            : Text(
                                'Restore',
                                style: ScreenSageTextStyles.bodySmall.copyWith(
                                    color: ScreenSageColors.textTertiary),
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content ────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      children: [
                        // ── Hero ──────────────────────────────
                        _HeroSection()
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: 0.08),

                        const SizedBox(height: 32),

                        // ── Feature list ──────────────────────
                        ..._features.asMap().entries.map(
                              (e) => _FeatureRow(
                                emoji: e.value.$1,
                                label: e.value.$2,
                                sub: e.value.$3,
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                        milliseconds: 100 + e.key * 60),
                                  )
                                  .slideX(begin: -0.04),
                            ),

                        const SizedBox(height: 28),

                        // ── Packages ──────────────────────────
                        if (_loadingPackages)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: ScreenSageColors.accent,
                              strokeWidth: 2,
                            ),
                          )
                        else if (_packages.isEmpty)
                          // ← NEW — error state when RevenueCat config is broken
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: ScreenSageColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: ScreenSageColors.border),
                              ),
                              child: Column(
                                children: [
                                  const Text('😔',
                                      style: TextStyle(fontSize: 32)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Could not load pricing',
                                    style: ScreenSageTextStyles.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Check your connection and try again.',
                                    style:
                                        ScreenSageTextStyles.bodySmall.copyWith(
                                      color: ScreenSageColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _loadingPackages = true);
                                      _loadPackages();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ScreenSageColors.accentSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: ScreenSageColors.accent
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        'Retry',
                                        style: ScreenSageTextStyles.bodyMedium
                                            .copyWith(
                                          color: ScreenSageColors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._packages.map(
                            (pkg) => _PackageCard(
                              package: pkg,
                              isSelected: _selected == pkg,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = pkg);
                              },
                            ).animate().fadeIn(delay: 500.ms),
                          ),

                        const SizedBox(height: 8),

                        // Social proof
                        _SocialProof().animate().fadeIn(delay: 600.ms),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Sticky CTA ────────────────────────────────
                _StickyBottom(
                  selected: _selected,
                  purchasing: _purchasing,
                  onPurchase: _purchase,
                  showSuccess: _showSuccess,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (
      '🧬',
      'Focus DNA',
      'Your personal focus archetype — built from every session',
    ),
    (
      '✨',
      'Focus Constellation',
      'A live star map of your focus. Share it. Own it.',
    ),
    (
      '📊',
      'Deep Analytics',
      'Monthly view, tag breakdown, focus mode insights',
    ),
    (
      '💰',
      'Earned Time',
      'Turn every focused minute into guilt-free phone time',
    ),
    (
      '🔒',
      'Scheduled Block Mode',
      'Coming soon — automatic focus windows',
    ),
  ];
}

// ── Hero Section ──────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated constellation icon
        _ConstellationHero(),

        const SizedBox(height: 24),

        Text(
          'Your focus,\nunlocked.',
          style: ScreenSageTextStyles.displayMedium.copyWith(
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          "Forest blocks your phone.\nScreenSage gives you back something real.",
          style: ScreenSageTextStyles.bodyLarge.copyWith(
            color: ScreenSageColors.textSecondary,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Animated mini constellation ───────────────────────────────────
class _ConstellationHero extends StatefulWidget {
  @override
  State<_ConstellationHero> createState() => _ConstellationHeroState();
}

class _ConstellationHeroState extends State<_ConstellationHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _twinkle,
      builder: (_, __) => CustomPaint(
        size: const Size(160, 100),
        painter: HeroStarPainter(twinkle: _twinkle.value),
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.emoji,
    required this.label,
    required this.sub,
  });

  final String emoji;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ScreenSageColors.accentSurface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: ScreenSageColors.accent.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: ScreenSageColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(sub,
                    style: ScreenSageTextStyles.bodySmall.copyWith(
                      color: ScreenSageColors.textTertiary,
                    )),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: ScreenSageColors.accent, size: 18),
        ],
      ),
    );
  }
}

// ── Package Card ──────────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  final Package package;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAnnual = package.packageType == PackageType.annual;

    // Calculate monthly equivalent for annual
    String? savingsBadge;
    String priceSubtitle = '';
    if (isAnnual) {
      savingsBadge = 'SAVE 40%';
      // Show monthly breakdown
      final annualPrice = package.storeProduct.price;
      final monthlyEquiv = annualPrice / 12;
      priceSubtitle =
          '\$${monthlyEquiv.toStringAsFixed(2)}/mo · billed annually';
    } else {
      priceSubtitle = 'billed monthly';
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? ScreenSageColors.accentSurface
              : ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? ScreenSageColors.accent : ScreenSageColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ScreenSageColors.accent.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? ScreenSageColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? ScreenSageColors.accent
                      : ScreenSageColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Color(0xFF001A0F))
                  : null,
            ),

            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAnnual ? 'Annual' : 'Monthly',
                        style: ScreenSageTextStyles.titleMedium,
                      ),
                      if (savingsBadge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: ScreenSageColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            savingsBadge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF001A0F),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    priceSubtitle,
                    style: ScreenSageTextStyles.bodySmall.copyWith(
                      color: ScreenSageColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              package.storeProduct.priceString,
              style: ScreenSageTextStyles.headlineMedium.copyWith(
                color: isSelected
                    ? ScreenSageColors.accent
                    : ScreenSageColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Social Proof ──────────────────────────────────────────────────
class _SocialProof extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No dark patterns. Ever.',
                  style: ScreenSageTextStyles.labelMedium.copyWith(
                    color: ScreenSageColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cancel anytime from App Store Settings. '
                  'No hidden charges. Trial ends, you decide.',
                  style: ScreenSageTextStyles.bodySmall.copyWith(
                    color: ScreenSageColors.textTertiary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky Bottom CTA ─────────────────────────────────────────────
class _StickyBottom extends StatelessWidget {
  const _StickyBottom({
    required this.selected,
    required this.purchasing,
    required this.onPurchase,
    required this.showSuccess,
  });

  final Package? selected;
  final bool purchasing;
  final VoidCallback onPurchase;
  final bool showSuccess;

  @override
  Widget build(BuildContext context) {
    final isAnnual = selected?.packageType == PackageType.annual;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: ScreenSageColors.background,
        border: Border(
          top: BorderSide(color: ScreenSageColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main CTA with success state ──────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: showSuccess
                // ── Success state ──
                ? Container(
                    key: const ValueKey('success'),
                    height: 58,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ScreenSageColors.accentSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: ScreenSageColors.accent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: ScreenSageColors.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Welcome to Premium! ✨',
                          style: ScreenSageTextStyles.titleMedium.copyWith(
                            color: ScreenSageColors.accent,
                          ),
                        ),
                      ],
                    ),
                  )
                // ── Normal purchase button ──
                : GestureDetector(
                    key: const ValueKey('purchase'),
                    onTap: (purchasing || selected == null) ? null : onPurchase,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: (purchasing || selected == null)
                            ? null
                            : const LinearGradient(
                                colors: [
                                  ScreenSageColors.accent,
                                  ScreenSageColors.violet,
                                ],
                              ),
                        color: (purchasing || selected == null)
                            ? ScreenSageColors.surface
                            : null,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: purchasing
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      ScreenSageColors.accent.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Center(
                        child: purchasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ScreenSageColors.accent,
                                ),
                              )
                            : Text(
                                'Start 7-Day Free Trial',
                                style:
                                    ScreenSageTextStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 10),

          // ── Fine print — hide on success ─────────────────
          AnimatedOpacity(
            opacity: showSuccess ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Text(
              isAnnual
                  ? 'Free for 7 days · Then ${selected?.storeProduct.priceString ?? ''}/year · Cancel anytime'
                  : 'Free for 7 days · Then ${selected?.storeProduct.priceString ?? ''}/month · Cancel anytime',
              style: ScreenSageTextStyles.bodySmall.copyWith(
                color: ScreenSageColors.textTertiary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
