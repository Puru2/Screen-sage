// ── Premium Card — live state aware ──────────────────────────────
import 'package:flutter/material.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.isPremium,
    required this.loading,
    required this.onUpgrade,
    required this.onManage,
  });

  final bool isPremium;
  final bool loading;
  final VoidCallback onUpgrade;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isPremium ? ScreenSageColors.violet : ScreenSageColors.accent)
                .withOpacity(0.15),
            ScreenSageColors.violet.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPremium ? ScreenSageColors.violet : ScreenSageColors.accent)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ScreenSageColors.accentSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPremium
                  ? Icons.workspace_premium_rounded
                  : Icons.workspace_premium_outlined,
              color:
                  isPremium ? ScreenSageColors.violet : ScreenSageColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ScreenSageColors.accent,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Premium ✨' : 'Free Plan',
                        style: ScreenSageTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPremium
                            ? 'All features unlocked'
                            : 'Upgrade to unlock DNA, Constellation & more',
                        style: ScreenSageTextStyles.bodySmall.copyWith(
                          color: ScreenSageColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          if (!loading)
            TextButton(
              onPressed: isPremium ? onManage : onUpgrade,
              style: TextButton.styleFrom(
                backgroundColor: isPremium
                    ? ScreenSageColors.surface
                    : ScreenSageColors.accent,
                foregroundColor: isPremium
                    ? ScreenSageColors.textSecondary
                    : const Color(0xFF001A0F),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isPremium
                      ? const BorderSide(color: ScreenSageColors.border)
                      : BorderSide.none,
                ),
              ),
              child: Text(
                isPremium ? 'Manage' : 'Upgrade',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
