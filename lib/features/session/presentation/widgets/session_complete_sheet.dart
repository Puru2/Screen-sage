import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../earned_time/presentation/bloc/earned_time_bloc.dart';
import '../../../streak/data/repositories/streak_repository.dart';
import '../../../streak/presentation/bloc/streak_bloc.dart';
import '../bloc/session_bloc.dart';

class SessionCompleteSheet extends StatelessWidget {
  const SessionCompleteSheet({
    super.key,
    required this.durationMinutes,
    required this.overrides,
  });

  final int durationMinutes;
  final int overrides;

  @override
  Widget build(BuildContext context) {
    HapticFeedback.heavyImpact();

    return Container(
      decoration: const BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ───────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ScreenSageColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 32),

          // ── Trophy ───────────────────────────────────────
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: ScreenSageColors.accentSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: ScreenSageColors.accent.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 40)),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.4, 0.4),
                duration: 700.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(),

          const SizedBox(height: 20),

          Text(
            'Session Complete!',
            style: ScreenSageTextStyles.headlineLarge,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 6),

          Text(
            overrides == 0
                ? 'Perfect session — zero overrides 🌿'
                : 'You focused for $durationMinutes minutes. Keep going.',
            style: ScreenSageTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 28),

          // ── Stats Row ────────────────────────────────────
          Row(
            children: [
              _StatCard(
                emoji: '⏱',
                label: 'Focus Time',
                value: '${durationMinutes}m',
              ),
              const SizedBox(width: 12),
              _StatCard(
                emoji: '🛡',
                label: 'Overrides',
                value: overrides == 0 ? 'None!' : '$overrides',
                valueColor: overrides == 0
                    ? ScreenSageColors.accent
                    : ScreenSageColors.danger,
              ),
              const SizedBox(width: 12),
              _StatCard(
                emoji: '💰',
                label: 'Earned',
                value: '+${durationMinutes}m',
                valueColor: ScreenSageColors.accent,
              ),
            ],
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          // ── Streak Badge — reads live from StreakBloc ────
          BlocBuilder<StreakBloc, StreakState>(
            builder: (context, state) {
              if (state is! StreakLoaded) return const SizedBox.shrink();
              final streak = state.data;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: streak.isOnFire
                      ? ScreenSageColors.amber.withOpacity(0.08)
                      : ScreenSageColors.violetSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: streak.isOnFire
                        ? ScreenSageColors.amber.withOpacity(0.35)
                        : ScreenSageColors.violet.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      streak.emoji,
                      style: const TextStyle(fontSize: 26),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(
                          duration: 2.seconds,
                          color: streak.isOnFire
                              ? ScreenSageColors.amber
                              : ScreenSageColors.violet,
                        ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streak.currentStreak == 0
                              ? 'First session complete!'
                              : '${streak.currentStreak} Day Streak!',
                          style: ScreenSageTextStyles.titleMedium.copyWith(
                            color: streak.isOnFire
                                ? ScreenSageColors.amber
                                : ScreenSageColors.violet,
                          ),
                        ),
                        Text(
                          streak.currentStreak == 0
                              ? 'Come back tomorrow to build your streak'
                              : streak.isLegendary
                                  ? '👑 Legendary — top 1% of users'
                                  : streak.isOnFire
                                      ? '🔥 You\'re on fire! Don\'t stop now'
                                      : '⚡ ${streak.longestStreak > streak.currentStreak ? 'Best: ${streak.longestStreak}d' : 'Personal best!'}',
                          style: ScreenSageTextStyles.bodySmall.copyWith(
                            color: ScreenSageColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1);
            },
          ),

          const SizedBox(height: 16),

          // ── Earned Time Reminder ─────────────────────────
          BlocBuilder<EarnedTimeBloc, EarnedTimeState>(
            builder: (context, state) {
              int balance = 0;
              if (state is EarnedTimeLoaded) balance = state.data.balanceMins;
              if (state is EarnedTimeFreeActive)
                balance = state.data.balanceMins;

              if (balance == 0) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ScreenSageColors.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ScreenSageColors.accent.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have ${balance}m of earned free time to spend!',
                        style: ScreenSageTextStyles.bodyMedium.copyWith(
                          color: ScreenSageColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 650.ms);
            },
          ),

          const SizedBox(height: 28),

          // ── Done Button ──────────────────────────────────
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SessionBloc>().add(SessionResetRequested());
            },
            child: const Text('Done'),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String emoji;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: ScreenSageColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              value,
              style: ScreenSageTextStyles.headlineMedium.copyWith(
                color: valueColor ?? ScreenSageColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: ScreenSageTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
