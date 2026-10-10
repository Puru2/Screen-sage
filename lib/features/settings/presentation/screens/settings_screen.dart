import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/premium_gate.dart';
import '../../../../core/services/revenue_cat_service.dart';
import '../../../../core/services/screen_time_service.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../onboarding/presentation/screens/philosophy_onboarding.dart';
import '../../../paywall/presentation/paywall_screen.dart';
import '../../data/models/block_window.dart';
import '../../data/models/user_settings.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/blocked_apps_sheet.dart';
import '../widgets/downtime_schedule_sheet.dart';
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
  int _blockedAppCount = 0;
  String? _username;
  bool _usernameLoading = true;
  String _notifLabel = 'Set reminder';

  @override
  void initState() {
    super.initState();
    _loadBlockedAppCount();
    _loadUsername();
    _loadNotifLabel();
  }

  Future<void> _loadNotifLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_enabled') ?? false;
    String label = 'Set reminder';
    if (enabled) {
      final hour = prefs.getInt('notif_hour') ?? 9;
      final minute = prefs.getInt('notif_minute') ?? 0;
      final period = hour < 12 ? 'AM' : 'PM';
      final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      label = '$h:${minute.toString().padLeft(2, '0')} $period';
    } else if (prefs.containsKey('notif_enabled')) {
      label = 'Off';
    }
    if (mounted) setState(() => _notifLabel = label);
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _usernameLoading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      if (mounted) {
        setState(() {
          _username = (data?['username'] as String?)?.trim();
          _usernameLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _usernameLoading = false);
    }
  }

  Future<void> _loadBlockedAppCount() async {
    final count = await ScreenTimeService.getSelectedAppCount();
    if (mounted) setState(() => _blockedAppCount = count);
  }

  Future<void> _showManagePlanSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManagePlanSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = PremiumGateProvider.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _usernameLoading
        ? null
        : (_username?.isNotEmpty == true
            ? _username
            : (user?.displayName?.isNotEmpty == true
                ? user!.displayName
                : 'ScreenSage User'));

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
                                _getInitials(displayName ?? user?.email ?? 'U'),
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
                          _usernameLoading
                              ? const SizedBox(
                                  height: 16,
                                  width: 100,
                                  child: LinearProgressIndicator(
                                    minHeight: 2,
                                  ),
                                )
                              : Text(
                                  displayName ?? 'ScreenSage User',
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
                isPremium: premium.isPremium,
                loading: !premium.loaded,
                onUpgrade: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PremiumGateProvider(
                        notifier: premiumNotifier,
                        child: PaywallScreen(
                          onSuccess: () =>
                              premiumNotifier.refreshAfterPurchase(),
                        ),
                      ),
                    ),
                  );
                },
                onManage: () => _showManagePlanSheet(context),
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

              BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
                  final settings = state is SettingsLoaded
                      ? state.settings
                      : const UserSettings();

                  return SettingsGroup(
                    items: [
                      SettingsItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        trailing: _trailingValue(_notifLabel),
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
                          _loadBlockedAppCount();
                        },
                      ),
                      SettingsItem(
                        icon: Icons.bedtime_outlined,
                        label: 'Downtime Schedule',
                        trailing: _trailingValue(
                          _downtimeSummary(settings.blockWindows),
                        ),
                        onTap: () => _showDowntimeSheet(context),
                      ),
                    ],
                  );
                },
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
  Future<void> _showNotificationSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => NotificationSheet(),
    );
    // Refresh the row's trailing label after the user saves/turns off.
    if (saved == true) _loadNotifLabel();
  }

  // ── Downtime Schedule Sheet ───────────────────────────────────────
  void _showDowntimeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: const DowntimeScheduleSheet(),
      ),
    );
  }

  String _downtimeSummary(List<BlockWindow> windows) {
    final active = windows.where((w) => w.enabled).toList();
    if (active.isEmpty) return 'Off';
    if (active.length == 1) return active.first.shortLabel;
    return '${active.length} windows';
  }

  Widget _trailingValue(String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            softWrap: false,
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

  String _getInitials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
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

class _ManagePlanSheet extends StatefulWidget {
  const _ManagePlanSheet();

  @override
  State<_ManagePlanSheet> createState() => _ManagePlanSheetState();
}

class _ManagePlanSheetState extends State<_ManagePlanSheet> {
  bool _loading = true;
  String? _productId;
  String? _priceString;
  DateTime? _expiresAt;
  bool _willRenew = true;
  PeriodType? _periodType;
  String? _planName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.active['Screen sage premium'];

      String? planName;
      String? priceString;

      try {
        final packages = await RevenueCatService.getPackages();
        final match = packages.firstWhere(
          (p) => p.storeProduct.identifier == entitlement!.productIdentifier,
          orElse: () => packages.first,
        );
        planName = match.storeProduct.title;
        priceString = match.storeProduct.priceString;
      } catch (_) {}

      if (entitlement == null) {
        setState(() => _loading = false);
        return;
      }

      final expiry = entitlement.expirationDate != null
          ? DateTime.tryParse(entitlement.expirationDate!)
          : null;

      try {
        final packages = await RevenueCatService.getPackages();
        final match = packages.firstWhere(
          (p) => p.storeProduct.identifier == entitlement.productIdentifier,
          orElse: () => packages.first,
        );
        priceString = match.storeProduct.priceString;
      } catch (_) {}

      setState(() {
        _productId = entitlement.productIdentifier;
        _planName = planName;
        _priceString = priceString;
        _expiresAt = expiry;
        _willRenew = entitlement.willRenew;
        _periodType = entitlement.periodType;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: ScreenSageColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ScreenSageColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Your Plan', style: ScreenSageTextStyles.titleLarge),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_productId == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No active subscription found.',
                  style: ScreenSageTextStyles.bodyMedium
                      .copyWith(color: ScreenSageColors.textSecondary),
                ),
              )
            else ...[
              _row('Plan', _planName ?? _productId ?? '—'),
              if (_priceString != null) _row('Price', _priceString!),
              if (_periodType != null)
                _row(
                    'Type',
                    _periodType == PeriodType.trial
                        ? 'Free Trial'
                        : _periodType == PeriodType.intro
                            ? 'Introductory'
                            : 'Standard'),
              if (_expiresAt != null)
                _row(
                  _willRenew ? 'Renews on' : 'Expires on',
                  _fmtDate(_expiresAt!),
                ),
              _row('Auto-Renew', _willRenew ? 'On' : 'Off'),
              const SizedBox(height: 20),
              Text(
                'To pause, cancel, or change your plan, manage it directly through the App Store.',
                style: ScreenSageTextStyles.bodySmall
                    .copyWith(color: ScreenSageColors.textTertiary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await RevenueCatService.openManageSubscriptions();
                  },
                  child: const Text('Manage in App Store'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: ScreenSageTextStyles.bodyMedium
                      .copyWith(color: ScreenSageColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: ScreenSageTextStyles.bodyMedium
                  .copyWith(color: ScreenSageColors.textSecondary),
            ),
            Text(
              value,
              style: ScreenSageTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
