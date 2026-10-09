import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/neon_theme.dart';

class NeonPanel extends StatelessWidget {
  const NeonPanel({super.key, required this.child, this.accent, this.padding});
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppSpacing.motionDuration,
    curve: Curves.easeOutCubic,
    padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.panelRadius),
      border: Border.all(
        color: accent?.withValues(alpha: 0.5) ?? AppColors.border,
      ),
      boxShadow: accent == null
          ? null
          : [
              (Theme.of(context).extension<NeonTheme>() ?? const NeonTheme())
                  .glow(accent!, strength: 0.3),
            ],
    ),
    child: child,
  );
}
