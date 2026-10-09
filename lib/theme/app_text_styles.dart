import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neural_idle/theme/app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle number({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get eyebrow => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );
}
