import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Rendering tier. [auto] picks [high] on large views and [medium] on small
/// ones; tests and screenshots pin [high].
enum VizQuality { auto, high, medium, low }

enum VizTransitionKind {
  /// First mount. Skipped when a clock is supplied or motion is reduced.
  intro,

  /// The stage index increased (one sequence even for multi-stage jumps).
  evolve,

  /// The stage index decreased (a paper was published).
  reset,

  /// The topology changed at the same stage index.
  crossfade,
}

/// A topology change being animated.
@immutable
class VizTransition {
  const VizTransition({
    required this.kind,
    required this.fromStage,
    required this.toStage,
  });

  final VizTransitionKind kind;
  final int fromStage;
  final int toStage;

  /// Stages crossed: 1 normally, more after offline progress.
  int get steps => (toStage - fromStage).abs();

  @override
  String toString() => 'VizTransition(${kind.name}, $fromStage → $toStage)';
}

/// A clock that never advances: the view paints exactly [value] and runs no
/// ticker. For tests, screenshots and thumbnails.
class FixedVizClock implements ValueListenable<Duration> {
  const FixedVizClock(this.value);

  @override
  final Duration value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Maps tokens per second to 0–1 on a log scale:
/// 0.5/s → 0.016, 1e3/s → 0.28, 1e6/s → 0.52, 1e12/s → 1.
///
/// Zero, negative and NaN give 0; infinity gives 1.
double productionEnergy(double tokensPerSecond) {
  if (tokensPerSecond.isNaN || tokensPerSecond <= 0) return 0;
  if (tokensPerSecond.isInfinite) return 1;
  final orders = math.log(tokensPerSecond) / math.ln10;
  return ((orders + 0.5) / 12.5).clamp(0.0, 1.0);
}
