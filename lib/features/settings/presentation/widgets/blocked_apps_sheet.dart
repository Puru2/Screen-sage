import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/screen_time_service.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class BlockedAppsSheet extends StatefulWidget {
  const BlockedAppsSheet({super.key, required this.initialCount});
  final int initialCount;

  @override
  State<BlockedAppsSheet> createState() => BlockedAppsSheetState();
}

class BlockedAppsSheetState extends State<BlockedAppsSheet> {
  late int _count;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  Future<void> _openPicker() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    await ScreenTimeService.showAppPicker();

    // Re-fetch count after picker closes
    final updated = await ScreenTimeService.getSelectedAppCount();
    if (mounted) {
      setState(() {
        _count = updated;
        _loading = false;
      });
      if (updated > 0) HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasApps = _count > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          Text('Blocked Apps', style: ScreenSageTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'These apps get blocked during every focus session.',
            style: ScreenSageTextStyles.bodyMedium
                .copyWith(color: ScreenSageColors.textSecondary),
          ),

          const SizedBox(height: 24),

          // Status card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: hasApps
                  ? ScreenSageColors.accentSurface
                  : ScreenSageColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasApps
                    ? ScreenSageColors.accent.withOpacity(0.3)
                    : ScreenSageColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasApps
                        ? ScreenSageColors.accent.withOpacity(0.15)
                        : ScreenSageColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      hasApps ? '🔒' : '📱',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasApps
                            ? '$_count app${_count == 1 ? '' : 's'} selected'
                            : 'No apps selected',
                        style: ScreenSageTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasApps
                            ? 'These will be blocked during sessions'
                            : 'Tap below to choose apps to block',
                        style: ScreenSageTextStyles.bodySmall.copyWith(
                          color: ScreenSageColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // How it works note
          if (!hasApps)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScreenSageColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ScreenSageColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: ScreenSageColors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'iOS will show a system picker. '
                      'Your selections are private — ScreenSage never sees which apps you chose.',
                      style: ScreenSageTextStyles.bodySmall
                          .copyWith(color: ScreenSageColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

          if (hasApps)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScreenSageColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ScreenSageColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 15, color: ScreenSageColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your app selections are stored privately on-device by iOS. '
                      'ScreenSage only knows the count, not which apps.',
                      style: ScreenSageTextStyles.bodySmall
                          .copyWith(color: ScreenSageColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Primary CTA
          GestureDetector(
            onTap: _loading ? null : _openPicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                gradient: _loading
                    ? null
                    : const LinearGradient(
                        colors: [
                          ScreenSageColors.accent,
                          ScreenSageColors.violet,
                        ],
                      ),
                color: _loading ? ScreenSageColors.surface : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _loading
                    ? null
                    : [
                        BoxShadow(
                          color: ScreenSageColors.accent.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ScreenSageColors.accent,
                        ),
                      )
                    : Text(
                        hasApps
                            ? 'Change Selected Apps'
                            : 'Choose Apps to Block',
                        style: ScreenSageTextStyles.titleMedium.copyWith(
                          color: const Color(0xFF001A0F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),

          // Clear selection — only if apps selected
          if (hasApps) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  // showAppPicker with nothing selected clears it
                  // OR call a dedicated clear method if you have one
                  await ScreenTimeService.showAppPicker();
                  final updated = await ScreenTimeService.getSelectedAppCount();
                  if (mounted) setState(() => _count = updated);
                },
                child: Text(
                  'Clear selection',
                  style: ScreenSageTextStyles.bodySmall
                      .copyWith(color: ScreenSageColors.textTertiary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
