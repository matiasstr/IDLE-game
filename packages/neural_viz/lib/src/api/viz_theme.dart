import 'package:flutter/material.dart';

/// Colors and caption font of the visualizations. The defaults are the Neural
/// Idle design tokens.
///
/// A view uses its own `theme` if given, else the [ThemeExtension] of this
/// type registered in the app's `ThemeData`, else these defaults.
@immutable
class NeuralVizTheme extends ThemeExtension<NeuralVizTheme> {
  const NeuralVizTheme({
    this.background = const Color(0xFF07090D),
    this.surface = const Color(0xFF0D1117),
    this.surfaceRaised = const Color(0xFF131A22),
    this.border = const Color(0xFF1E2833),
    this.textPrimary = const Color(0xFFE6EDF3),
    this.textSecondary = const Color(0xFF8B98A5),
    this.textMuted = const Color(0xFF56636F),
    this.signal = const Color(0xFF22D3EE),
    this.structure = const Color(0xFFA78BFA),
    this.success = const Color(0xFFA3E635),
    this.accent = const Color(0xFFF472B6),
    this.monoFontFamily = 'JetBrains Mono',
  });

  final Color background;
  final Color surface;

  /// Neuron fill.
  final Color surfaceRaised;

  /// Grid, plates and ring guides.
  final Color border;
  final Color textPrimary;

  /// Negative weights.
  final Color textSecondary;

  /// Captions.
  final Color textMuted;

  /// Cyan: tokens and the forward pass.
  final Color signal;

  /// Violet: neurons, weights, backprop and evolution.
  final Color structure;

  /// Lime: correct predictions and the reset ring.
  final Color success;

  /// Pink, used sparingly: the audio input, the AGI core rim and a wrong
  /// prediction.
  final Color accent;

  /// Captions and numbers. Registered by the app; falls back silently.
  final String monoFontFamily;

  @override
  NeuralVizTheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? signal,
    Color? structure,
    Color? success,
    Color? accent,
    String? monoFontFamily,
  }) {
    return NeuralVizTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      signal: signal ?? this.signal,
      structure: structure ?? this.structure,
      success: success ?? this.success,
      accent: accent ?? this.accent,
      monoFontFamily: monoFontFamily ?? this.monoFontFamily,
    );
  }

  @override
  NeuralVizTheme lerp(NeuralVizTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return NeuralVizTheme(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      border: c(border, other.border),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      signal: c(signal, other.signal),
      structure: c(structure, other.structure),
      success: c(success, other.success),
      accent: c(accent, other.accent),
      monoFontFamily: t < 0.5 ? monoFontFamily : other.monoFontFamily,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NeuralVizTheme &&
      other.background == background &&
      other.surface == surface &&
      other.surfaceRaised == surfaceRaised &&
      other.border == border &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary &&
      other.textMuted == textMuted &&
      other.signal == signal &&
      other.structure == structure &&
      other.success == success &&
      other.accent == accent &&
      other.monoFontFamily == monoFontFamily;

  @override
  int get hashCode => Object.hash(
    background,
    surface,
    surfaceRaised,
    border,
    textPrimary,
    textSecondary,
    textMuted,
    signal,
    structure,
    success,
    accent,
    monoFontFamily,
  );
}
