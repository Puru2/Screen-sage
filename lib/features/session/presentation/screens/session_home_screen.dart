// lib/features/session/presentation/screens/session_home_screen.dart
// Completely stripped and rebuilt

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/models/user_settings.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../streak/data/repositories/streak_repository.dart';
import '../../../streak/presentation/bloc/streak_bloc.dart';
import '../bloc/session_bloc.dart';
import '../widgets/focus_model_selector.dart';
import '../widgets/session_timer_arc.dart';
import '../widgets/duration_picker.dart';
import '../widgets/session_complete_sheet.dart';

class SessionHomeScreen extends StatefulWidget {
  const SessionHomeScreen({super.key});

  @override
  State<SessionHomeScreen> createState() => _SessionHomeScreenState();
}

class _SessionHomeScreenState extends State<SessionHomeScreen> {
  int _selectedDuration = 25;
  FocusMode _selectedMode = FocusMode.deep;
  String _intention = '';
  String _selectedTag = '';
  final _intentionController = TextEditingController();

  static const _tags = ['Study', 'Work', 'Reading', 'Exercise', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<SettingsBloc>().state;
      if (s is SettingsLoaded) {
        _applyFromSettings(s.settings);
      } else {
        context
            .read<SettingsBloc>()
            .stream
            .firstWhere((s) => s is SettingsLoaded)
            .then((s) {
          if (mounted && s is SettingsLoaded) _applyFromSettings(s.settings);
        });
      }
    });
  }

  void _applyFromSettings(UserSettings s) {
    setState(() {
      _selectedDuration = s.defaultDurationMins;
      _selectedMode = FocusMode.fromString(s.defaultFocusMode);
    });
  }

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionBloc, SessionState>(
      listenWhen: (_, curr) =>
          curr is SessionCompleted ||
          curr is SessionCancelled ||
          curr is SessionError,
      listener: (context, state) {
        if (state is SessionCompleted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            isDismissible: false,
            enableDrag: false,
            builder: (_) => BlocProvider.value(
              value: context.read<SessionBloc>(),
              child: SessionCompleteSheet(
                durationMinutes: state.durationMinutes,
                overrides: state.overrides,
              ),
            ),
          );
        }
        if (state is SessionError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: ScreenSageColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.read<SessionBloc>().add(SessionResetRequested());
            }
          });
        }
        if (state is SessionCancelled) {
          context.read<SessionBloc>().add(SessionResetRequested());
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: ScreenSageColors.background,
            body: Stack(
              children: [
                _AmbientGlow(isActive: state is SessionActive),
                SafeArea(child: _buildBody(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SessionState state) {
    if (state is SessionActive) return _ActiveView(state: state);
    if (state is SessionAuthorizing) {
      return const _StatusView(
        icon: Icons.shield_outlined,
        message: 'Requesting Screen Time permission...',
        showSpinner: true,
      );
    }
    if (state is SessionNotAuthorized) return const _NotAuthorizedView();
    if (state is SessionPickingApps) {
      return const _StatusView(
        icon: Icons.apps_outlined,
        message: 'Opening app selector...',
        showSpinner: true,
      );
    }
    return _buildIdle(context);
  }

  Widget _buildIdle(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = user?.displayName?.split(' ').first ?? 'there';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $name',
                          style: ScreenSageTextStyles.bodyMedium.copyWith(
                            color: ScreenSageColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ready to focus?',
                          style: ScreenSageTextStyles.titleLarge.copyWith(
                            color: ScreenSageColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    _StreakChip(),
                  ],
                ),
              ).animate().fadeIn(delay: 50.ms),

              const SizedBox(height: 32),

              // ── Timer Arc — center stage ──────────────────────
              Center(
                child: SessionTimerArc(
                  progress: 0.0,
                  remainingMinutes: 0,
                  remainingSeconds: 0,
                  isIdle: true,
                  durationMinutes: _selectedDuration,
                ),
              ).animate().fadeIn(delay: 100.ms).scale(
                    begin: const Offset(0.9, 0.9),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 24),

              // ── Duration Picker ───────────────────────────────
              DurationPicker(
                selectedDuration: _selectedDuration,
                onDurationChanged: (d) => setState(() => _selectedDuration = d),
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 20),

              // ── Focus Mode ────────────────────────────────────
              FocusModeSelector(
                selectedMode: _selectedMode,
                onModeChanged: (mode) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedMode = mode;
                    if (mode.type != FocusModeType.custom) {
                      _selectedDuration = mode.suggestedDuration;
                    }
                  });
                },
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 20),

              // ── Tag + Intention in one card ───────────────────
              _IntentionCard(
                controller: _intentionController,
                selectedTag: _selectedTag,
                tags: _tags,
                onTagChanged: (t) =>
                    setState(() => _selectedTag = _selectedTag == t ? '' : t),
                onIntentionChanged: (v) => _intention = v,
              ).animate().fadeIn(delay: 250.ms),

              const SizedBox(height: 16),

              // ── App Picker ────────────────────────────────────
              _AppPickerTile(
                onTap: () => context
                    .read<SessionBloc>()
                    .add(SessionAppPickerRequested()),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 28),

              // ── Start Button ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: ScreenSageColors.textPrimary,
                  ),
                  label: Text('Start ${_selectedMode.label}'),
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  void _start(BuildContext context) {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    context.read<SessionBloc>().add(
          SessionStartRequested(
            _selectedDuration,
            intention: _intention.trim(),
            focusMode: _selectedMode.typeString,
            tag: _selectedTag,
          ),
        );
    _intentionController.clear();
    _intention = '';
  }
}

// ── Streak Chip — minimal, top right ─────────────────────────────
class _StreakChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StreakBloc, StreakState>(
      builder: (context, state) {
        final streak = state is StreakLoaded ? state.data : StreakData.empty();
        return GestureDetector(
          onTap: () => _showStreakSheet(context, streak),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: streak.currentStreak > 0
                  ? ScreenSageColors.violetSurface
                  : ScreenSageColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: streak.isOnFire
                    ? ScreenSageColors.amber.withOpacity(0.4)
                    : streak.currentStreak > 0
                        ? ScreenSageColors.violet.withOpacity(0.3)
                        : ScreenSageColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: streak.isOnFire
                      ? ScreenSageColors.amber
                      : streak.currentStreak > 0
                          ? ScreenSageColors.violet
                          : ScreenSageColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  streak.currentStreak == 0 ? '0d' : '${streak.currentStreak}d',
                  style: ScreenSageTextStyles.labelMedium.copyWith(
                    color: streak.isOnFire
                        ? ScreenSageColors.amber
                        : streak.currentStreak > 0
                            ? ScreenSageColors.violet
                            : ScreenSageColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStreakSheet(BuildContext context, StreakData streak) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.local_fire_department_rounded,
              size: 56,
              color: streak.isOnFire
                  ? ScreenSageColors.amber
                  : ScreenSageColors.violet,
            ),
            const SizedBox(height: 12),
            Text(
              streak.currentStreak == 0
                  ? 'No streak yet'
                  : '${streak.currentStreak} Day Streak!',
              style: ScreenSageTextStyles.headlineLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StreakStat(
                    label: 'Current', value: '${streak.currentStreak}d'),
                _StreakStat(
                    label: 'Longest', value: '${streak.longestStreak}d'),
                _StreakStat(label: 'Total Days', value: '${streak.totalDays}'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              streak.currentStreak == 0
                  ? 'Complete a session to start your streak!'
                  : streak.isLegendary
                      ? '👑 Legendary — top 1% of users.'
                      : streak.isOnFire
                          ? 'You\'re on fire! Keep the chain alive.'
                          : 'Building a habit. Don\'t break the chain!',
              style: ScreenSageTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ScreenSageColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: ScreenSageTextStyles.titleLarge
                    .copyWith(color: ScreenSageColors.violet)),
            const SizedBox(height: 4),
            Text(label, style: ScreenSageTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Intention + Tag Card ──────────────────────────────────────────
class _IntentionCard extends StatelessWidget {
  const _IntentionCard({
    required this.controller,
    required this.selectedTag,
    required this.tags,
    required this.onTagChanged,
    required this.onIntentionChanged,
  });

  final TextEditingController controller;
  final String selectedTag;
  final List<String> tags;
  final ValueChanged<String> onTagChanged;
  final ValueChanged<String> onIntentionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intention text field
            TextField(
              controller: controller,
              onChanged: onIntentionChanged,
              maxLength: 80,
              style: ScreenSageTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'What are you working on? (optional)',
                hintStyle: ScreenSageTextStyles.bodyMedium.copyWith(
                  color: ScreenSageColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: ScreenSageColors.textTertiary,
                  size: 20,
                ),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              ),
            ),

            // Divider
            const Divider(height: 1, color: ScreenSageColors.border),

            // Tag chips
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(
                      Icons.label_outline_rounded,
                      size: 14,
                      color: ScreenSageColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    ...tags.map((tag) {
                      final isSelected = tag == selectedTag;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTagChanged(tag);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ScreenSageColors.accent
                                : ScreenSageColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? ScreenSageColors.accent
                                  : ScreenSageColors.border,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: ScreenSageTextStyles.labelSmall.copyWith(
                              color: isSelected
                                  ? const Color(0xFF001A0F)
                                  : ScreenSageColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Picker Tile ───────────────────────────────────────────────
class _AppPickerTile extends StatelessWidget {
  const _AppPickerTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ScreenSageColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.apps_rounded,
                color: ScreenSageColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Select Apps to Block',
                  style: ScreenSageTextStyles.bodyMedium),
            ),
            const Icon(Icons.chevron_right,
                color: ScreenSageColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Active Session View ───────────────────────────────────────────
class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.state});
  final SessionActive state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        // Intention + tag if set
        if (state.intention.isNotEmpty || state.tag.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ScreenSageColors.accentSurface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note_rounded,
                      color: ScreenSageColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (state.tag.isNotEmpty) state.tag,
                        if (state.intention.isNotEmpty) '"${state.intention}"',
                      ].join(' · '),
                      style: ScreenSageTextStyles.bodyMedium.copyWith(
                        color: ScreenSageColors.accent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (state.intention.isNotEmpty || state.tag.isNotEmpty)
          const SizedBox(height: 16),

        // Mode badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ScreenSageColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ScreenSageColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                FocusMode.fromString(state.focusMode).emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                FocusMode.fromString(state.focusMode).label,
                style: ScreenSageTextStyles.labelMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SessionTimerArc(
          progress: state.progress,
          remainingMinutes: state.remainingMinutes,
          remainingSeconds: state.remainingSecondsDisplay,
          isIdle: false,
          durationMinutes: state.durationMinutes,
        ),

        const SizedBox(height: 24),

        _MotivationalText(progress: state.progress),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: OutlinedButton.icon(
            onPressed: () => _confirmEnd(context),
            icon: const Icon(Icons.stop_circle_outlined,
                color: ScreenSageColors.danger, size: 18),
            label: const Text('End Session',
                style: TextStyle(color: ScreenSageColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ScreenSageColors.danger),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _confirmEnd(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.of(ctx).padding.bottom + 32,
        ),
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
            const Icon(Icons.warning_amber_rounded,
                color: ScreenSageColors.danger, size: 40),
            const SizedBox(height: 12),
            Text('End session early?',
                style: ScreenSageTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Progress will be saved but marked incomplete.',
              style: ScreenSageTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ScreenSageColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context
                    .read<SessionBloc>()
                    .add(SessionEndRequested(completed: false));
              },
              child: const Text('End Early'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Going 💪'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotivationalText extends StatelessWidget {
  const _MotivationalText({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final msg = progress < 0.25
        ? 'Getting started — you\'ve got this 💪'
        : progress < 0.5
            ? 'Building momentum — stay with it 🌱'
            : progress < 0.75
                ? 'Halfway there — hardest part is done 🔥'
                : progress < 0.9
                    ? 'Almost done — don\'t stop now ⚡'
                    : 'Final stretch — finish strong 🏆';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          msg,
          key: ValueKey(msg),
          style: ScreenSageTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Ambient Glow ──────────────────────────────────────────────────
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      left: -100,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              (isActive ? ScreenSageColors.accent : ScreenSageColors.violet)
                  .withOpacity(isActive ? 0.1 : 0.05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Views ──────────────────────────────────────────────────
class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.message,
    this.isError = false,
    this.showSpinner = false,
  });
  final IconData icon;
  final String message;
  final bool isError;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              const CircularProgressIndicator(
                  color: ScreenSageColors.accent, strokeWidth: 2)
            else
              Icon(icon,
                  size: 56,
                  color: isError
                      ? ScreenSageColors.danger
                      : ScreenSageColors.textSecondary),
            const SizedBox(height: 20),
            Text(message,
                style: ScreenSageTextStyles.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NotAuthorizedView extends StatelessWidget {
  const _NotAuthorizedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_outlined,
                size: 56, color: ScreenSageColors.danger),
            const SizedBox(height: 16),
            Text('Screen Time Permission Needed',
                style: ScreenSageTextStyles.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'ScreenSage needs Screen Time access to block apps during focus sessions.',
              style: ScreenSageTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context
                  .read<SessionBloc>()
                  .add(SessionAuthorizationRequested()),
              child: const Text('Grant Permission'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.read<SessionBloc>().add(SessionResetRequested()),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
