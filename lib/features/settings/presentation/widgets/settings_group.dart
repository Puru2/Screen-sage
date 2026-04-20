import 'package:flutter/material.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.items});
  final List<SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ScreenSageColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ScreenSageColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 0,
                  color: ScreenSageColors.border,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  const SettingsItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? ScreenSageColors.danger
                    : ScreenSageColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: ScreenSageTextStyles.bodyLarge.copyWith(
                    color: isDestructive
                        ? ScreenSageColors.danger
                        : ScreenSageColors.textPrimary,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ScreenSageColors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
