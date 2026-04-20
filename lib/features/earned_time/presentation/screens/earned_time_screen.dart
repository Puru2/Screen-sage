import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/repositories/earned_time_repository.dart';
import '../bloc/earned_time_bloc.dart';
import '../widgets/balance_arc.dart';
import '../widgets/time_spend_sheet.dart';

class EarnedTimeScreen extends StatelessWidget {
  const EarnedTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EarnedTimeBloc, EarnedTimeState>(
      listenWhen: (_, curr) =>
          curr is EarnedTimeFreeSessionExpired ||
          curr is EarnedTimeInsufficientBalance,
      listener: (context, state) {
        if (state is EarnedTimeFreeSessionExpired) {
          HapticFeedback.heavyImpact();
          _showTopBanner(
            context,
            '⏰ Free time ended — apps re-locked',
            ScreenSageColors.surface,
          );
        }
        if (state is EarnedTimeInsufficientBalance) {
          _showTopBanner(
            context,
            'Not enough balance — finish a session first',
            ScreenSageColors.dangerSurface,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: ScreenSageColors.background,
          body: switch (state) {
            EarnedTimeLoading() => const _LoadingView(),
            EarnedTimeError(:final message) => _ErrorView(message: message),
            EarnedTimeFreeActive(:final data, :final remainingSeconds) =>
              _FreeActiveView(data: data, remainingSeconds: remainingSeconds),
            EarnedTimeLoaded(:final data) => _RewardView(data: data),
            EarnedTimeSpending(:final data) =>
              _RewardView(data: data, isLoading: true),
            _ => _RewardView(data: EarnedTimeData.empty()),
          },
        );
      },
    );
  }

  static void _showTopBanner(BuildContext context, String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Has Balance — The Hero State ─────────────────────────────────
class _RewardView extends StatelessWidget {
  const _RewardView({required this.data, this.isLoading = false});

  final EarnedTimeData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasBalance = data.hasBalance;
    final balanceMins = data.balanceMins;

    return Stack(
      children: [
        // Ambient glow — stronger when balance exists
        Positioned(
          top: -80,
          right: -80,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ScreenSageColors.accent.withOpacity(hasBalance ? 0.12 : 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rewards',
                                  style: ScreenSageTextStyles.headlineLarge)
                              .animate()
                              .fadeIn(delay: 50.ms),
                          GestureDetector(
                            onTap: () => _showStatsSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: ScreenSageColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: ScreenSageColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.show_chart_rounded,
                                      size: 13,
                                      color: ScreenSageColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Text('History',
                                      style: ScreenSageTextStyles.bodySmall
                                          .copyWith(
                                              color: ScreenSageColors
                                                  .textTertiary)),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 50.ms),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Hero message ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: hasBalance
                            ? Column(
                                key: const ValueKey('has_balance'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('You\'ve earned',
                                      style: ScreenSageTextStyles.bodyLarge
                                          .copyWith(
                                        color: ScreenSageColors.textSecondary,
                                      )),
                                  Text(
                                    '$balanceMins minutes\nof freedom.',
                                    style: ScreenSageTextStyles.displayLarge
                                        .copyWith(
                                      color: ScreenSageColors.textPrimary,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('no_balance'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Focus first.',
                                      style: ScreenSageTextStyles.displayLarge
                                          .copyWith(
                                        color: ScreenSageColors.textPrimary,
                                      )),
                                  const SizedBox(height: 4),
                                  Text('Freedom follows.',
                                      style: ScreenSageTextStyles.displayLarge
                                          .copyWith(
                                        color: ScreenSageColors.accent,
                                      )),
                                ],
                              ),
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                    const SizedBox(height: 28),

                    // ── Arc ───────────────────────────────────────────
                    Center(
                      child: BalanceArc(
                        balanceMins: balanceMins,
                        maxMins: 180,
                      ).animate().fadeIn(delay: 150.ms).scale(
                            begin: const Offset(0.88, 0.88),
                            duration: 700.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ),

                    const SizedBox(height: 28),

                    if (hasBalance)
                      _UnlockSuggestions(balanceMins: balanceMins)
                          .animate()
                          .fadeIn(delay: 250.ms)
                          .slideY(begin: 0.08),

                    if (!hasBalance)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: ScreenSageColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: ScreenSageColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('How it works',
                                  style:
                                      ScreenSageTextStyles.titleMedium.copyWith(
                                    color: ScreenSageColors.textPrimary,
                                  )),
                              const SizedBox(height: 14),
                              _HowItWorksRow(
                                  step: '1', text: 'Complete a focus session'),
                              const SizedBox(height: 10),
                              _HowItWorksRow(
                                  step: '2',
                                  text:
                                      'Every minute focused = 1 minute earned'),
                              const SizedBox(height: 10),
                              _HowItWorksRow(
                                  step: '3',
                                  text:
                                      'Spend earned time to unlock blocked apps — guilt free'),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                    const Spacer(),

                    // ── Primary CTA ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: hasBalance
                            ? _SpendButton(
                                key: const ValueKey('spend'),
                                balanceMins: balanceMins,
                                isLoading: isLoading,
                                data: data,
                              )
                            : _GoFocusButton(
                                key: const ValueKey('focus'),
                                onTap: () => context.go('/session'),
                              ),
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StatsSheet(data: data),
    );
  }
}

// ── Unlock Suggestions ────────────────────────────────────────────
class _UnlockSuggestions extends StatelessWidget {
  const _UnlockSuggestions({required this.balanceMins});
  final int balanceMins;

  // Static suggestions — will be replaced by real blocked apps list
  // once Scheduled Blocks feature is built
  static const _apps = [
    _AppSuggestion(emoji: '📱', name: 'Social apps', mins: 30),
    _AppSuggestion(emoji: '🎵', name: 'Music', mins: 20),
    _AppSuggestion(emoji: '🎮', name: 'Games', mins: 45),
    _AppSuggestion(emoji: '📺', name: 'Streaming', mins: 60),
  ];

  @override
  Widget build(BuildContext context) {
    final affordable = _apps.where((a) => a.mins <= balanceMins).toList();
    if (affordable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Text(
            'What ${balanceMins}m can unlock',
            style: ScreenSageTextStyles.labelMedium.copyWith(
              color: ScreenSageColors.textTertiary,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: affordable.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _AppSuggestionCard(app: affordable[i]),
          ),
        ),
      ],
    );
  }
}

class _AppSuggestion {
  final String emoji;
  final String name;
  final int mins;
  const _AppSuggestion(
      {required this.emoji, required this.name, required this.mins});
}

class _AppSuggestionCard extends StatelessWidget {
  const _AppSuggestionCard({required this.app});
  final _AppSuggestion app;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ScreenSageColors.accentSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScreenSageColors.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(app.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(app.name,
              style: ScreenSageTextStyles.labelSmall
                  .copyWith(color: ScreenSageColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('~${app.mins}m',
              style: ScreenSageTextStyles.labelSmall
                  .copyWith(color: ScreenSageColors.accent)),
        ],
      ),
    );
  }
}

// ── How it works row ──────────────────────────────────────────────
class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({required this.step, required this.text});
  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: ScreenSageColors.accentSurface,
            shape: BoxShape.circle,
            border: Border.all(color: ScreenSageColors.accent.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              step,
              style: ScreenSageTextStyles.labelSmall.copyWith(
                color: ScreenSageColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: ScreenSageTextStyles.bodyMedium),
        ),
      ],
    );
  }
}

// ── Spend Button ──────────────────────────────────────────────────
class _SpendButton extends StatelessWidget {
  const _SpendButton({
    super.key,
    required this.balanceMins,
    required this.isLoading,
    required this.data,
  });

  final int balanceMins;
  final bool isLoading;
  final EarnedTimeData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => _showSpendSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : LinearGradient(
                  colors: [
                    ScreenSageColors.accent,
                    ScreenSageColors.violet,
                  ],
                ),
          color: isLoading ? ScreenSageColors.surface : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: ScreenSageColors.accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
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
                    // const Text('🎁', style: TextStyle(fontSize: 20)),
                    // const SizedBox(width: 10),
                    Text(
                      'Unlock $balanceMins min of free time',
                      style: ScreenSageTextStyles.titleMedium.copyWith(
                        color: const Color(0xFF001A0F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showSpendSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<EarnedTimeBloc>(),
        child: SpendTimeSheet(balanceMins: balanceMins),
      ),
    );
  }
}

// ── Go Focus CTA (empty state) ────────────────────────────────────
class _GoFocusButton extends StatelessWidget {
  const _GoFocusButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forest_outlined,
                  color: ScreenSageColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Start a session to earn free time',
                style: ScreenSageTextStyles.bodyMedium.copyWith(
                  color: ScreenSageColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Free Session Active — You're Free ────────────────────────────
class _FreeActiveView extends StatelessWidget {
  const _FreeActiveView({required this.data, required this.remainingSeconds});
  final EarnedTimeData data;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;

    return Stack(
      children: [
        // Strong ambient glow — celebratory
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ScreenSageColors.accent.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),

                    // ── Emotional header ───────────────────────────
                    Column(
                      children: [
                        Text('🎁', style: const TextStyle(fontSize: 64))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.08, 1.08),
                              duration: 1800.ms,
                              curve: Curves.easeInOut,
                            ),
                        const SizedBox(height: 20),
                        Text('You\'re free.',
                            style: ScreenSageTextStyles.displayLarge.copyWith(
                              color: ScreenSageColors.accent,
                            )).animate().fadeIn(delay: 50.ms),
                        const SizedBox(height: 6),
                        Text('No guilt. You earned this.',
                            style: ScreenSageTextStyles.bodyLarge.copyWith(
                              color: ScreenSageColors.textSecondary,
                            )).animate().fadeIn(delay: 100.ms),
                      ],
                    ),

                    const SizedBox(height: 44),

                    // ── Countdown ─────────────────────────────────
                    Column(
                      children: [
                        Text(
                          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                          style: ScreenSageTextStyles.timerDisplay.copyWith(
                            color: ScreenSageColors.textPrimary,
                            fontSize: 80,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -2,
                          ),
                        ).animate().fadeIn(delay: 150.ms),
                        const SizedBox(height: 6),
                        Text('of free time remaining',
                            style: ScreenSageTextStyles.bodyMedium.copyWith(
                              color: ScreenSageColors.textTertiary,
                            )).animate().fadeIn(delay: 200.ms),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Progress bar ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1.0 - (data.activeSession?.progress ?? 0.0),
                          minHeight: 4,
                          backgroundColor: ScreenSageColors.border,
                          valueColor: const AlwaysStoppedAnimation(
                              ScreenSageColors.accent),
                        ),
                      ),
                    ).animate().fadeIn(delay: 250.ms),

                    const Spacer(),

                    // ── Bank pill ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: ScreenSageColors.accentSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: ScreenSageColors.accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings_outlined,
                              color: ScreenSageColors.accent, size: 15),
                          const SizedBox(width: 7),
                          Text('Bank: ${data.balanceMins}m saved',
                              style: ScreenSageTextStyles.bodyMedium
                                  .copyWith(color: ScreenSageColors.accent)),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 20),

                    TextButton.icon(
                      onPressed: () => _confirmEndEarly(context),
                      icon: const Icon(Icons.lock_outline,
                          color: ScreenSageColors.textTertiary, size: 16),
                      label: Text('Re-lock early',
                          style: ScreenSageTextStyles.bodyMedium.copyWith(
                            color: ScreenSageColors.textTertiary,
                          )),
                    ).animate().fadeIn(delay: 350.ms),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmEndEarly(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.of(ctx).padding.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Re-lock early?', style: ScreenSageTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Unused free time is gone.',
              style: ScreenSageTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context
                    .read<EarnedTimeBloc>()
                    .add(EarnedTimeFreeSessionEnded());
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('Yes, Re-lock'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('Keep Enjoying'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Sheet ───────────────────────────────────────────────────
class _StatsSheet extends StatelessWidget {
  const _StatsSheet({required this.data});
  final EarnedTimeData data;

  @override
  Widget build(BuildContext context) {
    final efficiency = data.lifetimeEarned > 0
        ? (data.lifetimeSpent / data.lifetimeEarned * 100).round()
        : 0;
    final saved = data.lifetimeEarned - data.lifetimeSpent;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ScreenSageColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text('All Time Stats', style: ScreenSageTextStyles.headlineMedium),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatTile(
                    icon: '⚡',
                    label: 'Total Earned',
                    value: '${data.lifetimeEarned}m'),
                const SizedBox(width: 10),
                _StatTile(
                    icon: '🎯',
                    label: 'Total Spent',
                    value: '${data.lifetimeSpent}m'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatTile(
                    icon: '📊', label: 'Spend Rate', value: '$efficiency%'),
                const SizedBox(width: 10),
                _StatTile(
                    icon: '🏦',
                    label: 'Saved Up',
                    value: '${saved.clamp(0, 999)}m'),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScreenSageColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ScreenSageColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: ScreenSageColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Max bank is 180m. Unused minutes carry over between sessions.',
                      style: ScreenSageTextStyles.bodySmall,
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

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ScreenSageColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value,
                style: ScreenSageTextStyles.titleMedium
                    .copyWith(color: ScreenSageColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: ScreenSageTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Loading + Error ───────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: ScreenSageColors.accent,
        strokeWidth: 2,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              color: ScreenSageColors.danger, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: ScreenSageTextStyles.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                context.read<EarnedTimeBloc>().add(EarnedTimeLoadRequested()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
