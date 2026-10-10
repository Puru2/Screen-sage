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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScreenSageTextStyles.bodyLarge.copyWith(
                        color: isDestructive
                            ? ScreenSageColors.danger
                            : ScreenSageColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Trailing never wraps — on small screens it scales down
                  // and stays on a single line, right-aligned.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.48,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: trailing ??
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: ScreenSageColors.textTertiary,
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
