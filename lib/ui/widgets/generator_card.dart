import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class GeneratorCard extends StatelessWidget {
  const GeneratorCard({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.owned,
    required this.cost,
    required this.production,
    required this.canAfford,
    this.locked = false,
    this.onBuy,
    this.quantityLabel,
  });
  final IconData icon;
  final String name;
  final String description;
  final int owned;
  final String cost;
  final String production;
  final bool canAfford;
  final bool locked;
  final VoidCallback? onBuy;
  final String? quantityLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = canAfford && !locked;
    return NeonPanel(
      accent: active ? AppColors.neonLime : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  locked ? Icons.lock_outline_rounded : icon,
                  size: 20,
                  color: locked ? AppColors.textMuted : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked ? '???' : name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: locked
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked ? l10n.locked : description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!locked) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        production,
                        style: AppTextStyles.number(
                          size: 12,
                          color: AppColors.neonCyan,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.owned} $owned',
                        style: AppTextStyles.number(
                          size: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: active ? onBuy : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neonLime.withValues(alpha: 0.12),
                    foregroundColor: AppColors.neonLime,
                    disabledBackgroundColor: AppColors.surfaceRaised,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.buy,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        quantityLabel == null ? cost : '$cost · $quantityLabel',
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
        ],
      ),
    );
  }
}
