import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../features/paywall/presentation/paywall_screen.dart';
import '../theme/color_scheme.dart';
import '../theme/text_styles.dart';
import '../services/premium_gate.dart';

enum GateStyle {
  /// Full blur + lock icon overlay — for visual widgets like Constellation
  overlay,

  /// Subtle banner below content — "X days left in trial"
  banner,

  /// Replaces content entirely with a teaser card
  teaser,
}

class PremiumGateWidget extends StatelessWidget {
  const PremiumGateWidget({
    super.key,
    required this.child,
    required this.featureName,
    this.style = GateStyle.overlay,
    this.teaserDescription,
    this.teaserEmoji,
  });

  final Widget child;
  final String featureName;
  final GateStyle style;
  final String? teaserDescription;
  final String? teaserEmoji;

  @override
  Widget build(BuildContext context) {
    final notifier = PremiumGateProvider.of(context);

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        // Not loaded yet — show content without gate
        if (!notifier.loaded) return child;

        // Premium or in trial — show content fully
        // During trial: show banner only if <= 3 days left
        if (notifier.isPremium) {
          if (notifier.isInTrial &&
              notifier.trialDaysLeft != null &&
              notifier.trialDaysLeft! <= 3) {
            return _withTrialBanner(context, notifier.trialDaysLeft!);
          }
          return child;
        }

        // Not premium, not in trial — apply gate
        return switch (style) {
          GateStyle.overlay => _OverlayGate(
              featureName: featureName,
              child: child,
              onUnlock: () => _openPaywall(context, notifier),
            ),
          GateStyle.banner => _BannerGate(
              featureName: featureName,
              child: child,
              onUnlock: () => _openPaywall(context, notifier),
            ),
          GateStyle.teaser => _TeaserGate(
              featureName: featureName,
              description: teaserDescription ?? '',
              emoji: teaserEmoji ?? '✨',
              onUnlock: () => _openPaywall(context, notifier),
            ),
        };
      },
    );
  }

  Widget _withTrialBanner(BuildContext context, int daysLeft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        _TrialReminderBanner(
          daysLeft: daysLeft,
          onTap: () => _openPaywall(
            context,
            PremiumGateProvider.of(context),
          ),
        ),
      ],
    );
  }

  Future<void> _openPaywall(
      BuildContext context, PremiumNotifier notifier) async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumGateProvider(
          notifier: notifier,
          child: PaywallScreen(
            onSuccess: () => notifier.refresh(),
          ),
        ),
      ),
    );
    await notifier.refresh();
  }
}

// ── Overlay Gate — blurred content + lock ────────────────────────
class _OverlayGate extends StatelessWidget {
  const _OverlayGate({
    required this.child,
    required this.featureName,
    required this.onUnlock,
  });

  final Widget child;
  final String featureName;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred content underneath
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              child,
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),

        // Lock overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: onUnlock,
            child: Container(
              decoration: BoxDecoration(
                color: ScreenSageColors.background.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ScreenSageColors.accentSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ScreenSageColors.accent.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: ScreenSageColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    featureName,
                    style: ScreenSageTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Premium feature',
                    style: ScreenSageTextStyles.bodySmall
                        .copyWith(color: ScreenSageColors.textTertiary),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onUnlock,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ScreenSageColors.accent,
                            ScreenSageColors.violet,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ScreenSageColors.accent.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'Start Free Trial',
                        style: ScreenSageTextStyles.labelMedium.copyWith(
                          color: const Color(0xFF001A0F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),
      ],
    );
  }
}

// ── Banner Gate — content visible but with upgrade nudge ─────────
class _BannerGate extends StatelessWidget {
  const _BannerGate({
    required this.child,
    required this.featureName,
    required this.onUnlock,
  });

  final Widget child;
  final String featureName;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Faded content — visible but with opacity hint
        Opacity(opacity: 0.4, child: child),

        const SizedBox(height: 12),

        // Banner
        GestureDetector(
          onTap: onUnlock,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ScreenSageColors.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unlock $featureName with Premium',
                    style: ScreenSageTextStyles.labelMedium.copyWith(
                      color: ScreenSageColors.accent,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: ScreenSageColors.accent),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
      ],
    );
  }
}

// ── Teaser Gate — replaces content with a card ───────────────────
class _TeaserGate extends StatelessWidget {
  const _TeaserGate({
    required this.featureName,
    required this.description,
    required this.emoji,
    required this.onUnlock,
  });

  final String featureName;
  final String description;
  final String emoji;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: onUnlock,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ScreenSageColors.accent.withOpacity(0.08),
                ScreenSageColors.violet.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ScreenSageColors.accent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(featureName,
                  style: ScreenSageTextStyles.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                description,
                style: ScreenSageTextStyles.bodyMedium
                    .copyWith(color: ScreenSageColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      ScreenSageColors.accent,
                      ScreenSageColors.violet,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Start 7-Day Free Trial',
                  style: ScreenSageTextStyles.labelMedium.copyWith(
                    color: const Color(0xFF001A0F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }
}

// ── Trial Reminder Banner — <= 3 days left ────────────────────────
class _TrialReminderBanner extends StatelessWidget {
  const _TrialReminderBanner({required this.daysLeft, required this.onTap});

  final int daysLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ScreenSageColors.dangerSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ScreenSageColors.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(
              daysLeft == 0 ? '⚠️' : '⏳',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                daysLeft == 0
                    ? 'Trial ends today — subscribe to keep access'
                    : '$daysLeft day${daysLeft == 1 ? '' : 's'} left in your trial',
                style: ScreenSageTextStyles.labelSmall.copyWith(
                  color: ScreenSageColors.danger,
                ),
              ),
            ),
            Text(
              'Subscribe →',
              style: ScreenSageTextStyles.labelSmall.copyWith(
                color: ScreenSageColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }
}
