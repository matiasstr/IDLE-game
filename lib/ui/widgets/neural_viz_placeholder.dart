import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

/// Integration slot for Claude's neural network visualization.
class NeuralVizPlaceholder extends StatelessWidget {
  const NeuralVizPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => NeonPanel(
    child: Center(
      child: Text(
        'NEURAL NET VIZ',
        style: AppTextStyles.number(size: 12, color: AppColors.textMuted),
      ),
    ),
  );
}
