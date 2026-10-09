import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class ResourceTile extends StatelessWidget {
  const ResourceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.rate,
    this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? rate;
  final Color? accent;

  @override
  Widget build(BuildContext context) => NeonPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accent ?? AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.number(size: 28, color: accent)),
        if (rate != null) ...[
          const SizedBox(height: 4),
          Text(
            rate!,
            style: AppTextStyles.number(
              size: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}
