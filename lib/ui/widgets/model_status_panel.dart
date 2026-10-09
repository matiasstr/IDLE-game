import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class ModelStatusPanel extends StatelessWidget {
  const ModelStatusPanel({
    super.key,
    required this.architecture,
    required this.stage,
    required this.totalStages,
    required this.accuracy,
    required this.loss,
    this.nextArchitecture,
    required this.progressToNext,
  }) : assert(accuracy >= 0 && accuracy <= 1),
       assert(progressToNext >= 0 && progressToNext <= 1);
  final String architecture;
  final int stage;
  final int totalStages;
  final double accuracy;
  final String loss;
  final String? nextArchitecture;
  final double progressToNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.modelStatus.toUpperCase(), style: AppTextStyles.eyebrow),
          const SizedBox(height: 16),
          Text(
            l10n.architecture,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  architecture,
                  style: AppTextStyles.number(
                    size: 28,
                    color: AppColors.neonViolet,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  l10n.stageLabel(stage, totalStages),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.number(
                    size: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Metric(
            label: l10n.accuracy,
            value: '${(accuracy * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          _Metric(label: l10n.loss, value: loss),
          if (nextArchitecture != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _Metric(label: l10n.nextArchitecture, value: nextArchitecture!),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressToNext,
              minHeight: 4,
              color: AppColors.neonViolet,
              backgroundColor: AppColors.border,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: l10n.nextArchitecture,
              semanticsValue: '${(progressToNext * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 8),
            Text(
              l10n.progressLabel((progressToNext * 100).toStringAsFixed(0)),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(width: 8),
      Text(value, style: AppTextStyles.number(size: 12)),
    ],
  );
}
