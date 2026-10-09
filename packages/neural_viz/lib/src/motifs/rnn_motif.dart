import 'dart:math' as math;
import 'dart:ui';

import '../api/viz_types.dart';
import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/frame_buffers.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';
import '../scene/tap_tracker.dart';

/// A recurrent network unrolled in time.
///
/// Static: a 300° self-loop with an arrowhead on every hidden unit, and two
/// fading "echoes" of the hidden layers (t−1, t−2) up and to the left: ghost
/// bodies joined to the present by faint carry lines (one echo below 420 px,
/// none on the low tier).
///
/// Per frame: a dot circles each loop (not on the low tier), the echoes
/// glow faintly, and every 2.8 s the state is carried forward from t−2 to
/// t−1 to t. On a training wave the backprop turns through the loops and
/// continues into the echoes at ×0.6, then ×0.36: the vanishing gradient.
class RnnMotif extends Motif {
  const RnnMotif();

  static const _loopPeriod = 1.6;
  static const _carryPeriod = 2.8;
  static const _carryTravel = 0.32;

  /// Self-loop: radius as a fraction of the unit radius, and its direction
  /// (up and to the right).
  static const _loopScale = 0.52;
  static const _loopAngle = -0.30 * math.pi;

  /// Gap facing the unit: 60° of the loop's 360°.
  static const _loopGap = math.pi / 3;

  /// Echo scale per depth.
  static const _echoScale = [1.0, 0.92, 0.85];
  static const _echoAlpha = [0.0, 0.12, 0.06];
  static const _ghostAlpha = [0.0, 0.22, 0.12];
  static const _carryAlpha = [0.0, 0.16, 0.09];
  static const _gradient = [1.0, 0.6, 0.36];

  /// How many time echoes to draw at this size and tier.
  static int _depth(NetworkLayout layout, VizQuality quality) {
    if (quality == VizQuality.low || layout.layerCount < 3) return 0;
    return layout.size.width < 420 ? 1 : 2;
  }

  /// Echo [d] of neuron position ([x], [y]).
  static double _echoX(NetworkLayout layout, double x, int d) {
    final last = layout.layerCount - 2;
    final cx = 0.5 * (layout.layerX[1] + layout.layerX[last]);
    return cx + (x - cx) * _echoScale[d] - d * 0.035 * layout.size.width;
  }

  static double _echoY(NetworkLayout layout, double y, int d) {
    // Not `content.center`: this runs per frame and must not allocate.
    final cy = 0.5 * (layout.content.top + layout.content.bottom);
    return cy + (y - cy) * _echoScale[d] - d * 0.05 * layout.size.height;
  }

  /// Distance from a unit's center to its loop's center.
  static double _loopOffset(double r) {
    final rho = _loopScale * r;
    final half = _loopGap / 2;
    final s = rho * math.sin(half);
    return rho * math.cos(half) + math.sqrt(r * r - s * s);
  }

  // ------------------------------------------------------------- static

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    final depth = _depth(layout, ctx.quality);
    if (layout.isRings || depth == 0) return;
    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final carry = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (var d = depth; d >= 1; d--) {
      ghost.color = ctx.theme.structure.withValues(alpha: _ghostAlpha[d]);
      carry.color = ctx.theme.structure.withValues(alpha: _carryAlpha[d]);
      for (var l = 1; l < layout.layerCount - 1; l++) {
        for (var i = layout.layerStart[l]; i < layout.layerStart[l + 1]; i++) {
          final x = layout.x[i], y = layout.y[i], r = layout.radius[i];
          final x1 = _echoX(layout, x, d), y1 = _echoY(layout, y, d);
          final x0 = _echoX(layout, x, d - 1), y0 = _echoY(layout, y, d - 1);
          final r1 = _echoRadius(r, d);
          canvas.drawCircle(Offset(x1, y1), r1, ghost);
          // Carry line from the older state's rim to the newer one's.
          final dx = x0 - x1, dy = y0 - y1;
          final length = math.sqrt(dx * dx + dy * dy);
          final from = r1 + 2, to = length - _echoRadius(r, d - 1) - 2;
          if (to - from < 2) continue;
          canvas.drawLine(
            Offset(x1 + dx / length * from, y1 + dy / length * from),
            Offset(x1 + dx / length * to, y1 + dy / length * to),
            carry,
          );
        }
      }
    }
  }

  /// Body radius of echo [d] (0 is the unit itself).
  static double _echoRadius(double r, int d) =>
      d == 0 ? r : 0.82 * r * _echoScale[d];

  @override
  void paintOver(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.isRings) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = ctx.theme.structure.withValues(alpha: 0.4);
    const start = _loopAngle + math.pi + _loopGap / 2;
    const sweep = 2 * math.pi - _loopGap;
    for (var l = 1; l < layout.layerCount - 1; l++) {
      for (var i = layout.layerStart[l]; i < layout.layerStart[l + 1]; i++) {
        final r = layout.radius[i];
        final rho = _loopScale * r;
        final d = _loopOffset(r);
        final cx = layout.x[i] + d * math.cos(_loopAngle);
        final cy = layout.y[i] + d * math.sin(_loopAngle);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: rho),
          start,
          sweep,
          false,
          paint,
        );
        // Arrowhead where the loop re-enters the unit.
        const end = start + sweep;
        final ex = cx + rho * math.cos(end), ey = cy + rho * math.sin(end);
        final tx = -math.sin(end), ty = math.cos(end);
        final nx = math.cos(end), ny = math.sin(end);
        const head = 2.6;
        canvas
          ..drawLine(
            Offset(ex, ey),
            Offset(
              ex - head * tx + 0.8 * head * nx,
              ey - head * ty + 0.8 * head * ny,
            ),
            paint,
          )
          ..drawLine(
            Offset(ex, ey),
            Offset(
              ex - head * tx - 0.8 * head * nx,
              ey - head * ty - 0.8 * head * ny,
            ),
            paint,
          );
      }
    }
  }

  // ---------------------------------------------------------- per frame

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    final ma = ctx.motifAlpha;
    if (layout.isRings || ma <= 0 || layout.layerCount < 3) return;
    final t = ctx.t;
    final frame = ctx.frame;
    final colors = ctx.colors;
    final depth = _depth(layout, ctx.quality);
    final dots = ctx.quality != VizQuality.low;

    // Carry: every 2.8 s the state steps from t−2 to t−1 to t.
    final carryAge = t - (t / _carryPeriod).floorToDouble() * _carryPeriod;

    // Backprop through time: the newest wave still travelling back.
    var bptt = -1.0, amp = 0.0;
    if (!ctx.reducedMotion) {
      var newest = double.negativeInfinity;
      for (var w = 0; w < TapTracker.maxWaves; w++) {
        final start = ctx.taps.waveStart[w];
        if (start <= t && start > newest) {
          newest = start;
          amp = math.min(1.0, ctx.taps.waveAmp[w]);
        }
      }
      if (t - newest < 1.4) bptt = t - newest;
    }

    for (var l = 1; l < layout.layerCount - 1; l++) {
      // The core's backprop front reaches layer l at this wave age.
      final reach = 0.48 + 0.5 * (1 - l / (layout.layerCount - 1));
      for (var i = layout.layerStart[l]; i < layout.layerStart[l + 1]; i++) {
        final x = ctx.x[i], y = ctx.y[i], r = ctx.r[i];
        final rho = _loopScale * r;
        final off = _loopOffset(r);
        final lx = x + off * math.cos(_loopAngle);
        final ly = y + off * math.sin(_loopAngle);
        final index = i - layout.layerStart[1];

        // The gradient turns through the self-loop as the front passes.
        var loopGrad = 0.0;
        if (bptt >= 0) {
          loopGrad = amp * gauss(bptt - reach - 0.06, 0.05);
          if (loopGrad > 0.15) {
            _loop(frame, LineHue.structure, 0.42 * loopGrad * ma, lx, ly, rho);
          }
        }

        // A dot circling the loop.
        if (dots) {
          final q = (t / _loopPeriod + 0.137 * index) % 1.0;
          final angle =
              _loopAngle +
              math.pi +
              _loopGap / 2 +
              q * (2 * math.pi - _loopGap);
          final fade = smoothstep(0, 0.08, q) * smoothstep(1, 0.92, q);
          frame.glow.add(
            Sprites.dot,
            lx + rho * math.cos(angle),
            ly + rho * math.sin(angle),
            4.2,
            colors.structure,
            (0.55 + 0.35 * loopGrad) * fade * ma,
          );
        }

        // Echoes, oldest first.
        for (var d = depth; d >= 1; d--) {
          final ex = _echoX(layout, x, d), ey = _echoY(layout, y, d);
          final nx = _echoX(layout, x, d - 1), ny = _echoY(layout, y, d - 1);
          final er = _echoRadius(r, d);
          var alpha = _echoAlpha[d];
          // The carried state leaves the echo...
          final leave = carryAge - (depth - d) * _carryTravel;
          alpha += 0.12 * gauss(leave, 0.08) / d;
          // ...and the gradient arrives, weaker at each step back.
          var grad = 0.0;
          if (bptt >= 0) {
            grad =
                amp *
                _gradient[d] *
                gauss(bptt - reach - 0.16 - 0.13 * d, 0.06);
            alpha += 0.45 * grad;
          }
          frame.glow.add(
            Sprites.glow,
            ex,
            ey,
            3.4 * er,
            colors.structure,
            alpha * ma,
          );

          // Rim to rim along the carry line.
          final dx = nx - ex, dy = ny - ey;
          final length = math.sqrt(dx * dx + dy * dy);
          if (length < 1) continue;
          final ux = dx / length, uy = dy / length;
          final from = er + 2, span = length - _echoRadius(r, d - 1) - 2 - from;
          if (span < 2) continue;
          final sx = ex + ux * from, sy = ey + uy * from;

          // Carry pulse from this echo to the next newer state.
          if (leave >= 0 && leave < _carryTravel) {
            final u = easeInOutSine(leave / _carryTravel);
            final fade = math.sin(math.pi * leave / _carryTravel);
            frame.glow.add(
              Sprites.dot,
              sx + ux * span * u,
              sy + uy * span * u,
              3.6,
              colors.structure,
              0.6 * fade * ma,
            );
          }

          // The gradient flowing back along the carry line.
          if (grad > 0.1) {
            final at = reach + 0.16 + 0.13 * d;
            final u = clamp01((bptt - at + 0.13) / 0.13);
            final alpha = 0.55 * _gradient[d] * amp * ma;
            if (alpha >= 0.08 && u > 0 && u < 1) {
              // Backwards: from the newer state towards the echo.
              final hi = 1 - math.max(0.0, u - 0.45), lo = 1 - u;
              frame
                  .litBucket(LineHue.structure, alpha)
                  .add(
                    sx + ux * span * lo,
                    sy + uy * span * lo,
                    sx + ux * span * hi,
                    sy + uy * span * hi,
                  );
            }
          }
        }

        // The carried state lands in the present.
        if (depth > 0) {
          final land = carryAge - depth * _carryTravel;
          if (land >= 0) {
            ctx.actM[i] += 0.28 * math.exp(-land / 0.35) * ma;
          }
        }
      }
    }
  }

  /// The self-loop's 300° arc as lit segments.
  static void _loop(
    FrameBuffers frame,
    LineHue hue,
    double alpha,
    double cx,
    double cy,
    double radius,
  ) {
    if (alpha < 0.08) return;
    final bucket = frame.litBucket(hue, alpha);
    const segments = 10;
    const start = _loopAngle + math.pi + _loopGap / 2;
    const sweep = 2 * math.pi - _loopGap;
    var px = cx + radius * math.cos(start), py = cy + radius * math.sin(start);
    for (var k = 1; k <= segments; k++) {
      final a = start + sweep * k / segments;
      final nx = cx + radius * math.cos(a), ny = cy + radius * math.sin(a);
      bucket.add(px, py, nx, ny);
      px = nx;
      py = ny;
    }
  }
}
