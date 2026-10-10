import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class StatEntry {
  const StatEntry(this.label, this.value, {this.icon, this.accent});

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
}

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key, required this.entries});

  final List<StatEntry> entries;

  @override
  Widget build(BuildContext context) => NeonPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).stats.toUpperCase(),
          style: AppTextStyles.eyebrow,
        ),
        for (final entry in entries) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.icon != null) ...[
                Icon(
                  entry.icon,
                  size: 18,
                  color: entry.accent ?? AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  entry.value,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.number(size: 14, color: entry.accent),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
