import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';

@immutable
class NeonTheme extends ThemeExtension<NeonTheme> {
  const NeonTheme({
    this.primary = AppColors.neonCyan,
    this.model = AppColors.neonViolet,
    this.available = AppColors.neonLime,
    this.achievement = AppColors.neonPink,
    this.glowAlpha = 0.35,
    this.glowBlur = 20,
  });

  final Color primary;
  final Color model;
  final Color available;
  final Color achievement;
  final double glowAlpha;
  final double glowBlur;

  BoxShadow glow(Color color, {double strength = 1}) => BoxShadow(
    color: color.withValues(alpha: glowAlpha * strength),
    blurRadius: glowBlur,
  );

  @override
  NeonTheme copyWith({
    Color? primary,
    Color? model,
    Color? available,
    Color? achievement,
    double? glowAlpha,
    double? glowBlur,
  }) => NeonTheme(
    primary: primary ?? this.primary,
    model: model ?? this.model,
    available: available ?? this.available,
    achievement: achievement ?? this.achievement,
    glowAlpha: glowAlpha ?? this.glowAlpha,
    glowBlur: glowBlur ?? this.glowBlur,
  );

  @override
  NeonTheme lerp(covariant NeonTheme? other, double t) {
    if (other == null) return this;
    return NeonTheme(
      primary: Color.lerp(primary, other.primary, t)!,
      model: Color.lerp(model, other.model, t)!,
      available: Color.lerp(available, other.available, t)!,
      achievement: Color.lerp(achievement, other.achievement, t)!,
      glowAlpha: glowAlpha + (other.glowAlpha - glowAlpha) * t,
      glowBlur: glowBlur + (other.glowBlur - glowBlur) * t,
    );
  }
}
