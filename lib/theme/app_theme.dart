import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/neon_theme.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.neonCyan,
      onPrimary: AppColors.background,
      secondary: AppColors.neonViolet,
      onSecondary: AppColors.background,
      tertiary: AppColors.neonLime,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      error: AppColors.error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _spaceGroteskTheme(base.textTheme),
      extensions: const [NeonTheme()],
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.neonCyan,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.neonCyan,
        dividerColor: AppColors.border,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
      ),
    );
  }

  // google_fonts 9 uses material_ui.TextTheme; keep Flutter's TextTheme here.
  static TextTheme _spaceGroteskTheme(TextTheme theme) => theme.copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(textStyle: theme.displayLarge),
    displayMedium: GoogleFonts.spaceGrotesk(textStyle: theme.displayMedium),
    displaySmall: GoogleFonts.spaceGrotesk(textStyle: theme.displaySmall),
    headlineLarge: GoogleFonts.spaceGrotesk(textStyle: theme.headlineLarge),
    headlineMedium: GoogleFonts.spaceGrotesk(textStyle: theme.headlineMedium),
    headlineSmall: GoogleFonts.spaceGrotesk(textStyle: theme.headlineSmall),
    titleLarge: GoogleFonts.spaceGrotesk(textStyle: theme.titleLarge),
    titleMedium: GoogleFonts.spaceGrotesk(textStyle: theme.titleMedium),
    titleSmall: GoogleFonts.spaceGrotesk(textStyle: theme.titleSmall),
    bodyLarge: GoogleFonts.spaceGrotesk(textStyle: theme.bodyLarge),
    bodyMedium: GoogleFonts.spaceGrotesk(textStyle: theme.bodyMedium),
    bodySmall: GoogleFonts.spaceGrotesk(textStyle: theme.bodySmall),
    labelLarge: GoogleFonts.spaceGrotesk(textStyle: theme.labelLarge),
    labelMedium: GoogleFonts.spaceGrotesk(textStyle: theme.labelMedium),
    labelSmall: GoogleFonts.spaceGrotesk(textStyle: theme.labelSmall),
  );
}
