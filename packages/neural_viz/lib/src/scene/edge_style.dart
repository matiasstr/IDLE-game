import 'dart:math' as math;

import 'easing.dart';

/// How a weight looks at a given training contrast. Shared by the static
/// picture and the dynamic layer, so swapping one for the other is invisible.
abstract final class EdgeStyle {
  /// Quantized edge alphas: one draw call per level, sign and width.
  static const levels = [0.07, 0.13, 0.19, 0.26, 0.34, 0.43];

  /// Contrast buckets; the static picture is re-recorded only when the
  /// bucket changes.
  static const contrastSteps = 16;

  /// How "learned" the weights look, 0–1: half from accuracy, half from
  /// progress towards the next stage (1 at the last stage), so every new
  /// architecture visibly re-learns even once accuracy saturates.
  static double contrast(double accuracy, double progress, bool lastStage) {
    final p = lastStage ? 1.0 : progress;
    final c =
        0.5 * smoothstep(0.10, 0.90, accuracy) + 0.5 * smoothstep(0, 0.6, p);
    return (c * contrastSteps).roundToDouble() / contrastSteps;
  }

  /// Display strength: untrained weights all look alike (0.42); trained ones
  /// separate into strong and faint.
  static double strength(double weight, double contrast) =>
      lerp(0.42, math.pow(weight.abs(), 1.6).toDouble(), contrast);

  static double alpha(double strength, {bool highContrast = false}) {
    final a = 0.05 + 0.40 * strength;
    return highContrast ? math.max(a, 0.12) : a;
  }

  /// Index into [levels] closest to [alpha].
  static int level(double alpha) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < levels.length; i++) {
      final d = (levels[i] - alpha).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  static bool isWide(double strength) => strength > 0.75;

  static const width = 1.0, wideWidth = 1.5;
}
