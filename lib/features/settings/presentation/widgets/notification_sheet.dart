import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class NotificationSheet extends StatefulWidget {
  @override
  State<NotificationSheet> createState() => NotificationSheetState();
}

class NotificationSheetState extends State<NotificationSheet> {
  int _hour = 9;
  int _minute = 0;
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hour = prefs.getInt('notif_hour') ?? 9;
      _minute = prefs.getInt('notif_minute') ?? 0;
      _enabled = prefs.getBool('notif_enabled') ?? true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_enabled) {
        final granted = await NotificationService.requestPermission();

        if (!granted) {
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Notifications are disabled. Please allow them to enable reminders.',
                ),
                backgroundColor: ScreenSageColors.danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }

        final user = FirebaseAuth.instance.currentUser;
        final rawName = user?.displayName?.split(' ').first;
        final name = (rawName != null && rawName.trim().isNotEmpty)
            ? rawName.trim()
            : 'there';

        await NotificationService.scheduleDailyReminder(
          hour: _hour,
          minute: _minute,
          name: name,
        );

        await prefs.setInt('notif_hour', _hour);
        await prefs.setInt('notif_minute', _minute);
        await prefs.setBool('notif_enabled', true);
      } else {
        await NotificationService.cancelDailyReminder();
        await prefs.setBool('notif_enabled', false);
      }

      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save reminder: $e'),
            backgroundColor: ScreenSageColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Reminder', style: ScreenSageTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Get a nudge to focus every day at your chosen time.',
            style: ScreenSageTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Enable toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: ScreenSageColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScreenSageColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 20, color: ScreenSageColors.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Enable daily reminder',
                      style: ScreenSageTextStyles.bodyLarge),
                ),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: ScreenSageColors.accent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time picker — only shown when enabled
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                _enabled ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminder time', style: ScreenSageTextStyles.labelMedium),
                const SizedBox(height: 12),

                // Hour + minute wheels
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: ScreenSageColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ScreenSageColors.border),
                  ),
                  child: Row(
                    children: [
                      // Hour
                      Expanded(
                        child: _TimeWheel(
                          itemCount: 24,
                          selected: _hour,
                          label: (i) => i == 0
                              ? '12 AM'
                              : i < 12
                                  ? '$i AM'
                                  : i == 12
                                      ? '12 PM'
                                      : '${i - 12} PM',
                          onSelected: (i) => setState(() => _hour = i),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: ScreenSageColors.border,
                      ),
                      // Minute
                      Expanded(
                        child: _TimeWheel(
                          itemCount: 12,
                          selected: _minute ~/ 5,
                          label: (i) =>
                              '${(i * 5).toString().padLeft(2, '0')} min',
                          onSelected: (i) => setState(() => _minute = i * 5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Preview
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ScreenSageColors.accentSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: ScreenSageColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          size: 16, color: ScreenSageColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        _previewText(),
                        style: ScreenSageTextStyles.labelMedium
                            .copyWith(color: ScreenSageColors.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            secondChild: const SizedBox(height: 0),
          ),

          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: _enabled
                    ? const LinearGradient(
                        colors: [
                          ScreenSageColors.accent,
                          ScreenSageColors.violet,
                        ],
                      )
                    : null,
                color: _enabled ? null : ScreenSageColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: _enabled
                    ? null
                    : Border.all(color: ScreenSageColors.border),
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ScreenSageColors.accent,
                        ),
                      )
                    : Text(
                        _enabled ? 'Save Reminder' : 'Turn Off Notifications',
                        style: ScreenSageTextStyles.titleMedium.copyWith(
                          color: _enabled
                              ? const Color(0xFF001A0F)
                              : ScreenSageColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previewText() {
    final period = _hour < 12 ? 'AM' : 'PM';
    final displayHour = _hour == 0
        ? 12
        : _hour > 12
            ? _hour - 12
            : _hour;
    final displayMin = _minute.toString().padLeft(2, '0');
    return 'Reminder fires at $displayHour:$displayMin $period daily';
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.itemCount,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final int itemCount;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      itemExtent: 40,
      perspective: 0.003,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      controller: FixedExtentScrollController(initialItem: selected),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, i) => Center(
          child: Text(
            label(i),
            style: ScreenSageTextStyles.bodyLarge.copyWith(
              color: i == selected
                  ? ScreenSageColors.accent
                  : ScreenSageColors.textTertiary,
              fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
