import 'package:flutter/material.dart';
import 'package:neural_viz/neural_viz.dart';

/// Neural Idle design tokens, as used by the example's chrome. The view
/// itself reads the same values from [NeuralVizTheme].
abstract final class Palette {
  static const background = Color(0xFF07090D);
  static const surface = Color(0xFF0D1117);
  static const surfaceRaised = Color(0xFF131A22);
  static const border = Color(0xFF1E2833);
  static const borderStrong = Color(0xFF2B3746);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B98A5);
  static const textMuted = Color(0xFF56636F);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFFA78BFA);
  static const lime = Color(0xFFA3E635);
  static const pink = Color(0xFFF472B6);
}

const kMono = 'JetBrains Mono';
const kSans = 'Space Grotesk';

/// Text styles of the chrome. Numbers are always mono.
abstract final class Styles {
  /// Uppercase section labels and frame annotations.
  static const label = TextStyle(
    fontFamily: kMono,
    fontSize: 10.5,
    height: 1.3,
    letterSpacing: 1.1,
    fontWeight: FontWeight.w500,
    color: Palette.textMuted,
  );

  /// Numeric readouts.
  static const value = TextStyle(
    fontFamily: kMono,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: Palette.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const body = TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    height: 1.35,
    color: Palette.textSecondary,
  );

  static const bodyStrong = TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: Palette.textPrimary,
  );

  static const hint = TextStyle(
    fontFamily: kSans,
    fontSize: 11.5,
    height: 1.35,
    color: Palette.textMuted,
  );

  static const title = TextStyle(
    fontFamily: kSans,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: Palette.textPrimary,
  );
}

ThemeData buildExampleTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: kSans,
    colorScheme: const ColorScheme.dark(
      primary: Palette.cyan,
      secondary: Palette.violet,
      tertiary: Palette.lime,
      error: Palette.pink,
      surface: Palette.surface,
      onSurface: Palette.textPrimary,
      outline: Palette.border,
      outlineVariant: Palette.border,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Palette.background,
    canvasColor: Palette.background,
    dividerColor: Palette.border,
    splashFactory: NoSplash.splashFactory,
    focusColor: Palette.cyan.withValues(alpha: 0.12),
    hoverColor: Palette.textPrimary.withValues(alpha: 0.04),
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x5522D3EE),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Palette.surfaceRaised,
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: Styles.hint.copyWith(color: Palette.textSecondary),
      waitDuration: const Duration(milliseconds: 500),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.dragged)
            ? Palette.textMuted
            : Palette.borderStrong,
      ),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 2,
      activeTrackColor: Palette.cyan,
      inactiveTrackColor: Palette.border,
      disabledActiveTrackColor: Palette.textMuted,
      disabledInactiveTrackColor: Palette.border,
      thumbColor: Palette.textPrimary,
      disabledThumbColor: Palette.textMuted,
      overlayColor: Palette.cyan.withValues(alpha: 0.10),
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 6,
        disabledThumbRadius: 4,
        elevation: 0,
        pressedElevation: 0,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    extensions: const [NeuralVizTheme()],
  );
}
