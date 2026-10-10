import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/block_window.dart';
import '../../data/models/user_settings.dart';
import '../bloc/settings_bloc.dart';

/// Manage daily recurring app-block windows ("downtime").
///
/// Windows are stored in [UserSettings.blockWindows] and mirrored to iOS —
/// shields come up automatically inside each window and lift when it ends.
class DowntimeScheduleSheet extends StatelessWidget {
  const DowntimeScheduleSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final settings =
            state is SettingsLoaded ? state.settings : const UserSettings();
        final windows = settings.blockWindows;

        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
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
              Text('Downtime Schedule',
                  style: ScreenSageTextStyles.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Your blocked apps stay shielded during these windows — every day. '
                'Need a breather? Unlock time with your earned minutes; '
                'the shield comes back when the break ends.',
                style: ScreenSageTextStyles.bodyMedium.copyWith(
                    color: ScreenSageColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (windows.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ScreenSageColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ScreenSageColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text('🌙', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'No downtime windows yet. Add one to block apps on a daily schedule.',
                          style: ScreenSageTextStyles.bodyMedium.copyWith(
                            color: ScreenSageColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...windows.map(
                  (w) => _WindowRow(
                    window: w,
                    onToggle: (enabled) => _save(
                      context,
                      settings,
                      windows
                          .map((x) =>
                              x.id == w.id ? w.copyWith(enabled: enabled) : x)
                          .toList(),
                    ),
                    onDelete: () => _save(
                      context,
                      settings,
                      windows.where((x) => x.id != w.id).toList(),
                    ),
                    onEdit: () => _openEditor(context, existing: w),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add window'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save(
    BuildContext context,
    UserSettings settings,
    List<BlockWindow> windows,
  ) {
    HapticFeedback.selectionClick();
    context
        .read<SettingsBloc>()
        .add(SettingsSaveRequested(settings.copyWith(blockWindows: windows)));
  }

  Future<void> _openEditor(BuildContext context, {BlockWindow? existing}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: ScreenSageColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: _WindowEditorSheet(existing: existing),
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.window,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final BlockWindow window;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: window.enabled
            ? ScreenSageColors.accentSurface
            : ScreenSageColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: window.enabled
              ? ScreenSageColors.accent.withOpacity(0.35)
              : ScreenSageColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      window.label,
                      maxLines: 1,
                      style: ScreenSageTextStyles.titleMedium.copyWith(
                        color: window.enabled
                            ? ScreenSageColors.textPrimary
                            : ScreenSageColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    window.enabled
                        ? 'Active daily'
                        : 'Paused — tap switch to resume',
                    style: ScreenSageTextStyles.bodySmall.copyWith(
                      color: ScreenSageColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: window.enabled,
            activeColor: ScreenSageColors.accent,
            onChanged: onToggle,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: ScreenSageColors.danger),
            tooltip: 'Remove window',
          ),
        ],
      ),
    );
  }
}

/// Add / edit a single window: start time, end time, or all-day.
class _WindowEditorSheet extends StatefulWidget {
  const _WindowEditorSheet({this.existing});

  final BlockWindow? existing;

  @override
  State<_WindowEditorSheet> createState() => _WindowEditorSheetState();
}

class _WindowEditorSheetState extends State<_WindowEditorSheet> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _allDay;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _allDay = existing?.isFullDay ?? false;
    _start = existing == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(
            hour: (existing.startMinutes ~/ 60) % 24,
            minute: existing.startMinutes % 60,
          );
    _end = existing == null
        ? const TimeOfDay(hour: 17, minute: 0)
        : TimeOfDay(
            hour: (existing.endMinutes ~/ 60) % 24,
            minute: existing.endMinutes % 60,
          );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  void _save() {
    final startM = _allDay ? 0 : _start.hour * 60 + _start.minute;
    final endM = _allDay ? 1439 : _end.hour * 60 + _end.minute;

    if (!_allDay && startM == endM) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start and end time can\'t be identical.'),
        ),
      );
      return;
    }

    final window = BlockWindow(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      startMinutes: startM,
      endMinutes: endM,
      enabled: widget.existing?.enabled ?? true,
    );

    final bloc = context.read<SettingsBloc>();
    final state = bloc.state;
    final settings =
        state is SettingsLoaded ? state.settings : const UserSettings();
    final windows = [...settings.blockWindows];
    final idx = windows.indexWhere((w) => w.id == window.id);
    if (idx >= 0) {
      windows[idx] = window;
    } else {
      windows.add(window);
    }

    HapticFeedback.mediumImpact();
    bloc.add(SettingsSaveRequested(settings.copyWith(blockWindows: windows)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
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

          Text(isEditing ? 'Edit window' : 'New downtime window',
              style: ScreenSageTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Windows repeat every day until you pause or remove them.',
            style: ScreenSageTextStyles.bodyMedium
                .copyWith(color: ScreenSageColors.textSecondary),
          ),

          const SizedBox(height: 24),

          // All-day toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: ScreenSageColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScreenSageColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child:
                      Text('All day', style: ScreenSageTextStyles.titleMedium),
                ),
                Switch(
                  value: _allDay,
                  activeColor: ScreenSageColors.accent,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              ],
            ),
          ),

          if (!_allDay) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Starts',
                    time: _start,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: 'Ends',
                    time: _end,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Windows can cross midnight (e.g. 10:00 PM – 2:00 AM).',
              style: ScreenSageTextStyles.bodySmall
                  .copyWith(color: ScreenSageColors.textTertiary),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(isEditing ? 'Save changes' : 'Add window'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ScreenSageColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ScreenSageColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ScreenSageTextStyles.labelSmall
                    .copyWith(color: ScreenSageColors.textTertiary),
              ),
              const SizedBox(height: 4),
              Text(
                time.format(context),
                style: ScreenSageTextStyles.titleLarge
                    .copyWith(color: ScreenSageColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
