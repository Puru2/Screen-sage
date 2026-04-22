import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/revenue_cat_service.dart';
import '../../../../core/services/screen_time_service.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../onboarding/presentation/screens/philosophy_onboarding.dart';
import '../../../paywall/presentation/paywall_screen.dart';
import '../../data/models/user_settings.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/blocked_apps_sheet.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/premium_card.dart';
import '../widgets/settings_group.dart';
import '../widgets/signout_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => curr is Unauthenticated,
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.go('/onboarding');
        }
      },
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  bool _isPremium = false;
  bool _premiumLoading = true;
  int _blockedAppCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _loadBlockedAppCount();
  }

  Future<void> _loadBlockedAppCount() async {
    final count = await ScreenTimeService.getSelectedAppCount();
    if (mounted) setState(() => _blockedAppCount = count);
  }

  Future<void> _checkPremium() async {
    final result = await RevenueCatService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = result;
        _premiumLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: ScreenSageColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Text('Profile', style: ScreenSageTextStyles.headlineLarge)
                  .animate()
                  .fadeIn(delay: 100.ms),

              const SizedBox(height: 32),

              // ── Avatar + Name Card ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ScreenSageColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ScreenSageColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: ScreenSageColors.accentSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ScreenSageColors.accent.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: user?.photoURL != null
                          ? ClipOval(
                              child: Image.network(user!.photoURL!,
                                  fit: BoxFit.cover))
                          : Center(
                              child: Text(
                                _getInitials(
                                    user?.displayName ?? user?.email ?? 'U'),
                                style: ScreenSageTextStyles.titleLarge
                                    .copyWith(color: ScreenSageColors.accent),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'ScreenSage User',
                            style: ScreenSageTextStyles.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: ScreenSageTextStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _ProviderBadge(user: user),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

              const SizedBox(height: 24),

              PremiumCard(
                isPremium: _isPremium,
                loading: _premiumLoading,
                onUpgrade: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaywallScreen(
                        onSuccess: () => _checkPremium(),
                      ),
                    ),
                  );
                  _checkPremium(); // refresh after paywall closes
                },
                onManage: () {
                  // Opens App Store subscription management
                  RevenueCatService.openManageSubscriptions();
                },
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

              const SizedBox(height: 24),

              // ── Focus Settings — LIVE from SettingsBloc ────────
              Text('Focus', style: ScreenSageTextStyles.labelMedium)
                  .animate()
                  .fadeIn(delay: 250.ms),

              const SizedBox(height: 12),

              BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
                  final settings = state is SettingsLoaded
                      ? state.settings
                      : const UserSettings();

                  return SettingsGroup(
                    items: [
                      // Daily Goal
                      SettingsItem(
                        icon: Icons.flag_outlined,
                        label: 'Daily Focus Goal',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmtMins(settings.dailyGoalMins),
                              style: ScreenSageTextStyles.bodyMedium.copyWith(
                                color: ScreenSageColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 18, color: ScreenSageColors.textTertiary),
                          ],
                        ),
                        onTap: () => _showDailyGoalSheet(context, settings),
                      ),
                      // Default Duration
                      SettingsItem(
                        icon: Icons.timer_outlined,
                        label: 'Default Duration',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${settings.defaultDurationMins}m',
                              style: ScreenSageTextStyles.bodyMedium.copyWith(
                                color: ScreenSageColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 18, color: ScreenSageColors.textTertiary),
                          ],
                        ),
                        onTap: () =>
                            _showDefaultDurationSheet(context, settings),
                      ),
                      // Default Focus Mode
                      SettingsItem(
                        icon: Icons.tune_outlined,
                        label: 'Default Focus Mode',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${FocusMode.fromString(settings.defaultFocusMode).emoji} '
                              '${FocusMode.fromString(settings.defaultFocusMode).label}',
                              style: ScreenSageTextStyles.bodyMedium.copyWith(
                                color: ScreenSageColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 18, color: ScreenSageColors.textTertiary),
                          ],
                        ),
                        onTap: () => _showDefaultModeSheet(context, settings),
                      ),
                    ],
                  );
                },
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 24),

              // ── App Settings ────────────────────────────────────
              Text('Settings', style: ScreenSageTextStyles.labelMedium)
                  .animate()
                  .fadeIn(delay: 350.ms),
              const SizedBox(height: 12),

              SettingsGroup(
                items: [
                  SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    trailing: _trailingValue('Set reminder'),
                    onTap: () => _showNotificationSheet(context),
                  ),
                  SettingsItem(
                    icon: Icons.apps_outlined,
                    label: 'Blocked Apps',
                    trailing: _trailingValue(
                      _blockedAppCount > 0
                          ? '$_blockedAppCount app${_blockedAppCount == 1 ? '' : 's'}'
                          : 'None',
                    ),
                    onTap: () async {
                      await _showBlockedAppsSheet(context);
                      _loadBlockedAppCount(); // refresh count after sheet closes
                    },
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 24),

              Text('Support', style: ScreenSageTextStyles.labelMedium)
                  .animate()
                  .fadeIn(delay: 450.ms),

              const SizedBox(height: 12),

              SettingsGroup(
                items: [
                  SettingsItem(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Our Philosophy',
                    trailing: _trailingValue('Why ScreenSage'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhilosophyOnboarding(
                          isFromSettings: true,
                        ),
                      ),
                    ),
                  ),
                  SettingsItem(
                    icon: Icons.help_outline,
                    label: 'Help & FAQ',
                    onTap: () {},
                  ),
                  SettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () {},
                  ),
                  SettingsItem(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    onTap: () {},
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 24),

              SignOutButton()
                  .animate()
                  .fadeIn(delay: 550.ms)
                  .slideY(begin: 0.05),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => _showDeleteAccountDialog(context),
                  child: Text(
                    'Delete Account',
                    style: ScreenSageTextStyles.bodySmall
                        .copyWith(color: ScreenSageColors.danger),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBlockedAppsSheet(BuildContext context) async {
    final count = await ScreenTimeService.getSelectedAppCount();
    if (!mounted) return;

    await showModalBottomSheet(
      // ← add await here
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlockedAppsSheet(initialCount: count),
    );
  }

  // ── Notification Sheet ──────────────────────────────────────────
  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => NotificationSheet(),
    );
  }

  Widget _trailingValue(String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: ScreenSageTextStyles.bodyMedium
                .copyWith(color: ScreenSageColors.accent),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 18, color: ScreenSageColors.textTertiary),
        ],
      );

  // ── Daily Goal Sheet ─────────────────────────────────────────────
  void _showDailyGoalSheet(BuildContext context, UserSettings settings) {
    final goals = [30, 60, 90, 120, 150, 180, 240];
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ScreenSageColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Daily Focus Goal',
                  style: ScreenSageTextStyles.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'How much do you want to focus each day?',
                style: ScreenSageTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: goals.map((mins) {
                  final isSelected = mins == settings.dailyGoalMins;
                  return GestureDetector(
                    onTap: () {
                      context.read<SettingsBloc>().add(
                            SettingsSaveRequested(
                              settings.copyWith(dailyGoalMins: mins),
                            ),
                          );
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ScreenSageColors.accent
                            : ScreenSageColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? ScreenSageColors.accent
                              : ScreenSageColors.border,
                        ),
                      ),
                      child: Text(
                        _fmtMins(mins),
                        style: ScreenSageTextStyles.titleMedium.copyWith(
                          color: isSelected
                              ? const Color(0xFF001A0F)
                              : ScreenSageColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Default Duration Sheet ───────────────────────────────────────
  void _showDefaultDurationSheet(BuildContext context, UserSettings settings) {
    final durations = [5, 10, 15, 20, 25, 30, 45, 50, 60, 90];
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ScreenSageColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Default Duration',
                  style: ScreenSageTextStyles.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Pre-selected duration when you open the app',
                style: ScreenSageTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: durations.map((mins) {
                  final isSelected = mins == settings.defaultDurationMins;
                  return GestureDetector(
                    onTap: () {
                      context.read<SettingsBloc>().add(
                            SettingsSaveRequested(
                              settings.copyWith(defaultDurationMins: mins),
                            ),
                          );
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ScreenSageColors.accent
                            : ScreenSageColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? ScreenSageColors.accent
                              : ScreenSageColors.border,
                        ),
                      ),
                      child: Text(
                        '${mins}m',
                        style: ScreenSageTextStyles.titleMedium.copyWith(
                          color: isSelected
                              ? const Color(0xFF001A0F)
                              : ScreenSageColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Default Focus Mode Sheet ─────────────────────────────────────
  void _showDefaultModeSheet(BuildContext context, UserSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ScreenSageColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Default Focus Mode',
                  style: ScreenSageTextStyles.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Pre-selected mode when you open the app',
                style: ScreenSageTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              ...FocusMode.all.map((mode) {
                final isSelected = mode.typeString == settings.defaultFocusMode;
                return GestureDetector(
                  onTap: () {
                    context.read<SettingsBloc>().add(
                          SettingsSaveRequested(
                            settings.copyWith(
                                defaultFocusMode: mode.typeString),
                          ),
                        );
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ScreenSageColors.accentSurface
                          : ScreenSageColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? ScreenSageColors.accent.withOpacity(0.5)
                            : ScreenSageColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(mode.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mode.label,
                                  style: ScreenSageTextStyles.titleMedium),
                              Text(mode.description,
                                  style: ScreenSageTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: ScreenSageColors.accent, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ScreenSageColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account', style: ScreenSageTextStyles.titleMedium),
        content: Text(
          'This permanently deletes your account and all data. This cannot be undone.',
          style: ScreenSageTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Wire delete account later — requires re-auth
            },
            child: Text(
              'Delete',
              style: TextStyle(color: ScreenSageColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Provider Badge ─────────────────────────────────────────────────
class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final provider = _getProvider();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ScreenSageColors.accentSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ScreenSageColors.accent.withOpacity(0.3)),
      ),
      child: Text(
        provider,
        style: ScreenSageTextStyles.labelSmall.copyWith(
          color: ScreenSageColors.accent,
        ),
      ),
    );
  }

  String _getProvider() {
    if (user == null) return 'Email';
    final providers = user!.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) return '  Google';
    if (providers.contains('apple.com')) return ' Apple';
    return '✉ Email';
  }
}
