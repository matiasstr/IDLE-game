import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
    required this.name,
    required this.description,
    this.effect,
    required this.cost,
    required this.canAfford,
    required this.purchased,
    this.onBuy,
  });
  final String name;
  final String description;
  final String? effect;
  final String cost;
  final bool canAfford;
  final bool purchased;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = canAfford && !purchased;
    return NeonPanel(
      accent: active ? AppColors.neonLime : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                purchased
                    ? Icons.check_circle_outline_rounded
                    : Icons.science_outlined,
                size: 20,
                color: purchased ? AppColors.neonLime : AppColors.neonViolet,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (effect != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonViolet.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    effect!,
                    style: AppTextStyles.number(
                      size: 10,
                      color: AppColors.neonViolet,
                    ),
                  ),
                ),
              if (purchased)
                Text(
                  l10n.purchased,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.neonLime),
                )
              else
                FilledButton(
                  onPressed: active ? onBuy : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neonLime.withValues(alpha: 0.12),
                    foregroundColor: AppColors.neonLime,
                    disabledBackgroundColor: AppColors.surfaceRaised,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.buy),
                      const SizedBox(width: 8),
                      Text(
                        cost,
                        style: AppTextStyles.number(
                          size: 12,
                          color: active
                              ? AppColors.neonLime
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
