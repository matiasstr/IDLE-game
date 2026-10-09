import 'dart:ui';

import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/hash.dart';
import '../scene/motif.dart';
import '../scene/tap_tracker.dart';

/// A small dense network with ReLU hidden units.
///
/// Static: a ReLU ramp glyph in every hidden unit.
///
/// Per frame: each inference pass (every 3.2 s, and each training wave)
/// draws a fresh sparsity pattern: about 40% of the hidden units output zero
/// and stay dark. When a pass ends, the argmax output gets a thin cyan ring
/// (a training wave shows its prediction check instead).
class MlpMotif extends Motif {
  const MlpMotif();

  static const _pass = 3.2;
  static const _dead = 0.4;
  static const _ring = 0.6;

  @override
  void paintOver(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.isRings) return;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = ctx.theme.textMuted.withValues(alpha: 0.9);
    for (var l = 1; l < layout.layerCount - 1; l++) {
      for (var i = layout.layerStart[l]; i < layout.layerStart[l + 1]; i++) {
        final x = layout.x[i], y = layout.y[i], r = layout.radius[i];
        // max(0, x): flat, then a 45° ramp.
        canvas.drawPath(
          Path()
            ..moveTo(x - 0.52 * r, y + 0.26 * r)
            ..lineTo(x - 0.02 * r, y + 0.26 * r)
            ..lineTo(x + 0.46 * r, y - 0.22 * r),
          pen,
        );
      }
    }
  }

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    final ma = ctx.motifAlpha;
    if (layout.isRings || ma <= 0 || layout.layerCount < 3) return;
    final t = ctx.t;
    final seed = layout.topology.seed;

    // The current and previous sparsity patterns: pass starts and wave
    // starts, whichever came last.
    final pass = (t / _pass).floor();
    var latest = pass * _pass, previous = (pass - 1) * _pass;
    var latestKey = pass, previousKey = pass - 1;
    var waveAlive = false;
    if (!ctx.reducedMotion) {
      for (var w = 0; w < TapTracker.maxWaves; w++) {
        final start = ctx.taps.waveStart[w];
        if (start > t || start <= previous) continue;
        if (t - start < TapTracker.waveLife) waveAlive = true;
        final key = 1 << 30 | ctx.taps.waveSerial[w];
        if (start > latest) {
          previous = latest;
          previousKey = latestKey;
          latest = start;
          latestKey = key;
        } else {
          previous = start;
          previousKey = key;
        }
      }
    }
    final blend = smoothstep(0, 0.3, t - latest);

    for (var l = 1; l < layout.layerCount - 1; l++) {
      for (var i = layout.layerStart[l]; i < layout.layerStart[l + 1]; i++) {
        final now = hash01(seed, 4100 + latestKey, i) < _dead ? 1.0 : 0.0;
        final before = hash01(seed, 4100 + previousKey, i) < _dead ? 1.0 : 0.0;
        final dead = lerp(before, now, blend) * ma;
        // Live units keep a faint ember (a positive output); dead ones go
        // dark, so the sparsity pattern reads at a glance.
        ctx.actS[i] = ctx.actS[i] * (1 - 0.9 * dead) + 0.1 * (ma - dead);
        ctx.actM[i] = ctx.actM[i] * (1 - 0.75 * dead) + 0.1 * (ma - dead);
      }
    }

    // Argmax ring at the end of each pass.
    final age = t - pass * _pass;
    if (pass > 0 && age < _ring && !waveAlive) {
      final out = ctx.predicted;
      final q = age / _ring;
      final alpha = 0.7 * smoothstep(0, 0.06, age) * (1 - q) * (1 - q) * ma;
      final radius = 1.75 * ctx.r[out] + 2 * easeOutCubic(q);
      ctx.frame.cores.add(
        Sprites.ring,
        ctx.x[out],
        ctx.y[out],
        radius * 48 / 21,
        ctx.colors.signal,
        alpha,
      );
      ctx.actS[out] += 0.3 * (1 - q) * ma;
    }
  }
}
