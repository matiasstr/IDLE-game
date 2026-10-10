import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../api/viz_types.dart';
import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/edge_style.dart';
import '../scene/energy_track.dart';
import '../scene/frame_buffers.dart';
import '../scene/hash.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';
import '../scene/tap_tracker.dart';

/// Rosenblatt's perceptron as a textbook figure that integrates and fires.
///
/// Static: a Σ | step glyph in the output unit, a dashed "+1" bias node,
/// edge widths by |w| rank, mid-edge weight labels on wide views, a faint
/// membrane track with thirds and an axon stub.
///
/// Per frame: every signal that reaches the output fills a third of a violet
/// membrane arc; the third arrival fires the output (a hard cyan flash and
/// a comet down the axon) and empties the arc. When signals are dense the
/// arc takes more arrivals (a tick each), so the unit never fires more than
/// about once a second. A training tap fills the arc at once and fires when
/// its forward front lands.
///
/// The membrane is a pure function of time: arrivals are counted in closed
/// form from the signal slots (the same formulas as `VizScene._signals`),
/// relative to the last tap that fired the unit.
class PerceptronMotif extends Motif {
  const PerceptronMotif();

  /// Membrane arc radius beyond the output rim.
  static const _gap = 4.5;

  /// Fill easing per arrival, then the fire flash.
  static const _fill = 0.12, _flash = 0.18, _comet = 0.36;

  /// A tap's forward front reaches the output after this long.
  static const _tapFire = 0.42;

  /// The unit fires at most about this often (per second), so dense
  /// signals never make it blink.
  static const _maxFireRate = 1.1;

  // ------------------------------------------------------------- static

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.isRings || layout.edgeCount == 0) return;
    // Edge widths by |w| rank (1.0 / 1.8 / 2.6 px): a wider stroke under
    // the shared edge, in the same color and alpha.
    final order = List.generate(
      layout.edgeCount,
      (e) => e,
    )..sort((a, b) => layout.weight[a].abs().compareTo(layout.weight[b].abs()));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (var rank = 0; rank < order.length; rank++) {
      final e = order[rank];
      final q = order.length == 1 ? 1.0 : rank / (order.length - 1);
      final width = 1.0 + 1.6 * q;
      if (width <= 1.2) continue;
      final s = ctx.strength[e];
      final alpha = EdgeStyle.alpha(s, highContrast: ctx.highContrast);
      final negative = layout.weight[e] < 0;
      paint
        ..strokeWidth = width
        ..color = (negative ? ctx.theme.textSecondary : ctx.theme.structure)
            .withValues(alpha: (negative ? 0.5 : 0.75) * alpha);
      final a = layout.edgeSrc[e], b = layout.edgeDst[e];
      canvas.drawLine(
        Offset(layout.x[a], layout.y[a]),
        Offset(layout.x[b], layout.y[b]),
        paint,
      );
    }
  }

  @override
  void paintOver(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.isRings) return;
    final theme = ctx.theme;
    final out = layout.neuronCount - 1;
    final ox = layout.x[out], oy = layout.y[out], big = layout.radius[out];
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Membrane track (its ticks depend on the signal rate: per frame).
    final track = big + _gap;
    canvas.drawCircle(
      Offset(ox, oy),
      track,
      hairline..color = theme.border.withValues(alpha: 0.9),
    );

    // Axon stub: where the output's spike leaves.
    final axon = _axonLength(layout);
    if (axon > 8) {
      final x0 = ox + track + 3, x1 = ox + track + axon;
      canvas.drawLine(
        Offset(x0, oy),
        Offset(x1, oy),
        hairline..color = theme.structure.withValues(alpha: 0.22),
      );
      canvas.drawLine(
        Offset(x1 - 3.5, oy - 3),
        Offset(x1, oy),
        hairline..color = theme.structure.withValues(alpha: 0.3),
      );
      canvas.drawLine(Offset(x1 - 3.5, oy + 3), Offset(x1, oy), hairline);
    }

    _paintGlyph(canvas, theme.textSecondary, theme.border, ox, oy, big);
    _paintBias(canvas, ctx, out);
    if (layout.size.width >= 560 && layout.captions.isNotEmpty) {
      _paintLabels(canvas, ctx, out);
    }
  }

  /// Σ on the left half, a step function on the right, split by a hairline.
  static void _paintGlyph(
    Canvas canvas,
    Color ink,
    Color split,
    double x,
    double y,
    double radius,
  ) {
    final h = 0.56 * radius, w = 0.36 * radius;
    canvas.drawLine(
      Offset(x, y - 0.6 * radius),
      Offset(x, y + 0.6 * radius),
      Paint()
        ..strokeWidth = 1
        ..color = split,
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.9)
      ..isAntiAlias = true;
    final sx = x - 0.44 * radius;
    canvas.drawPath(
      Path()
        ..moveTo(sx + w / 2, y - h / 2)
        ..lineTo(sx - w / 2, y - h / 2)
        ..lineTo(sx + 0.12 * w, y)
        ..lineTo(sx - w / 2, y + h / 2)
        ..lineTo(sx + w / 2, y + h / 2),
      pen,
    );
    final tx = x + 0.44 * radius, step = 0.32 * h;
    canvas.drawPath(
      Path()
        ..moveTo(tx - w / 2 - 1, y + step)
        ..lineTo(tx, y + step)
        ..lineTo(tx, y - step)
        ..lineTo(tx + w / 2 + 1, y - step),
      pen,
    );
  }

  /// A dashed "+1" bias unit above the inputs, feeding the output.
  static void _paintBias(Canvas canvas, StaticContext ctx, int out) {
    final layout = ctx.layout;
    final theme = ctx.theme;
    final bias = _biasPosition(layout);
    if (bias == null) return;
    final (bx, by, br) = bias;
    final ox = layout.x[out], oy = layout.y[out], big = layout.radius[out];

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true
      ..color = theme.structure.withValues(alpha: 0.55);
    const dashes = 10;
    final rect = Rect.fromCircle(center: Offset(bx, by), radius: br);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        rect,
        2 * math.pi * i / dashes,
        math.pi / dashes,
        false,
        dash,
      );
    }

    // Dashed edge to the output rim.
    final dx = ox - bx, dy = oy - by;
    final length = math.sqrt(dx * dx + dy * dy);
    final ux = dx / length, uy = dy / length;
    final from = br + 3, to = length - big - _gap - 3;
    dash.color = theme.structure.withValues(alpha: 0.28);
    for (var d = from; d < to; d += 7) {
      final e = math.min(d + 3.5, to);
      canvas.drawLine(
        Offset(bx + ux * d, by + uy * d),
        Offset(bx + ux * e, by + uy * e),
        dash,
      );
    }

    final label = TextPainter(
      text: TextSpan(
        text: '+1',
        style: TextStyle(
          fontFamily: theme.monoFontFamily,
          fontSize: (0.85 * br).clamp(7.0, 11.0),
          fontWeight: FontWeight.w500,
          color: theme.textSecondary.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    label.paint(
      canvas,
      Offset(bx - label.width / 2 - 0.5, by - label.height / 2),
    );
    label.dispose();
  }

  /// Center and radius of the bias node, or null when there is no room.
  static (double, double, double)? _biasPosition(NetworkLayout layout) {
    final first = layout.layerStart[0];
    final br = math.max(6.0, 0.62 * layout.r);
    final by = math.max(
      layout.y[first] - 0.95 * layout.pitch,
      layout.content.top + br - 6,
    );
    if (layout.y[first] - by < layout.r + br + 6) return null;
    return (layout.layerX[0], by, br);
  }

  static double _axonLength(NetworkLayout layout) {
    final out = layout.neuronCount - 1;
    final right = layout.x[out] + layout.radius[out] + _gap;
    return math.min(40.0, layout.size.width - 14 - right);
  }

  /// "w1 .42" above each input edge, at 40% of its length.
  static void _paintLabels(Canvas canvas, StaticContext ctx, int out) {
    final layout = ctx.layout;
    final theme = ctx.theme;
    final style = TextStyle(
      fontFamily: theme.monoFontFamily,
      // Sized with the network, and never below 9 px: this is the first
      // thing a new player reads.
      fontSize: (0.75 * layout.r).clamp(9.0, 12.0),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: ctx.highContrast ? theme.textPrimary : theme.textSecondary,
    );
    for (var e = 0; e < layout.edgeCount; e++) {
      final a = layout.edgeSrc[e], b = layout.edgeDst[e];
      if (b != out) continue;
      final index = a - layout.layerStart[layout.layerOf[a]] + 1;
      _label(
        canvas,
        'w$index ${_weightText(layout.weight[e])}',
        style,
        layout.x[a] + layout.radius[a],
        layout.y[a],
        layout.x[b] - layout.radius[b],
        layout.y[b],
      );
    }
    final bias = _biasPosition(layout);
    if (bias != null) {
      final (bx, by, br) = bias;
      final w = 2 * hash01(layout.topology.seed, 990) - 1;
      _label(
        canvas,
        'b ${_weightText(w)}',
        style,
        bx + br,
        by,
        layout.x[out] - layout.radius[out],
        layout.y[out],
      );
    }
  }

  static void _label(
    Canvas canvas,
    String text,
    TextStyle style,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final mx = lerp(x1, x2, 0.4), my = lerp(y1, y2, 0.4);
    final angle = math.atan2(y2 - y1, x2 - x1);
    canvas
      ..save()
      ..translate(mx, my)
      ..rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height - 2.5));
    canvas.restore();
    painter.dispose();
  }

  static String _weightText(double w) {
    final v = (w.abs() * 100).round().clamp(0, 99);
    final digits = v < 10 ? '0$v' : '$v';
    return '${w < 0 ? '−' : ''}.$digits';
  }

  // ---------------------------------------------------------- per frame

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    final ma = ctx.motifAlpha;
    if (layout.isRings || ma <= 0) return;
    final out = layout.neuronCount - 1;
    final t = ctx.t;
    final speed = EnergyTrack.speed(ctx.energy);

    // The most recent tap wave (taps don't animate with reduced motion).
    var tap = double.negativeInfinity;
    if (!ctx.reducedMotion) {
      for (var i = 0; i < TapTracker.maxWaves; i++) {
        final start = ctx.taps.waveStart[i];
        if (start <= t && start > tap) tap = start;
      }
    }
    final tapFire = tap + _tapFire;

    // Arrivals since the last tap fired the unit (or since the start).
    final count = _arrivals(ctx, ctx.flow);
    final since = _scratchSince;
    // A third per arrival, unless signals are so dense that the unit would
    // fire more than about once a second.
    final per = math.max(3, (_scratchRate / _maxFireRate).ceil());
    var base = 0;
    if (t >= tapFire) {
      base = _arrivals(ctx, ctx.flow - (t - tapFire) * speed);
    } else if (tap.isFinite) {
      // Before this tap fires: measure from the tap before it, if any.
      var previous = double.negativeInfinity;
      for (var i = 0; i < TapTracker.maxWaves; i++) {
        final start = ctx.taps.waveStart[i];
        if (start < tap && start > previous) previous = start;
      }
      final fire = previous + _tapFire;
      if (fire.isFinite && fire <= t) {
        base = _arrivals(ctx, ctx.flow - (t - fire) * speed);
      }
    }
    final n = math.max(0, count - base);
    final level = n % per;

    var fill = level / per;
    var fireAge = double.infinity;
    var tipBoost = 0.0;
    if (n > 0 && level == 0 && since < _fill + _comet) {
      // The last arrival completed the membrane: fill, then fire.
      if (since < _fill) {
        fill = (per - 1 + easeOutCubic(since / _fill)) / per;
        tipBoost = 1;
      } else {
        fireAge = since - _fill;
      }
    } else if (level > 0 && since < _fill) {
      fill = (level - 1 + easeOutCubic(since / _fill)) / per;
      tipBoost = 1;
    }
    if (t >= tap && t < tapFire) {
      // A tap charges the membrane at once; it fires on landing.
      fill = lerp(fill, 1, easeOutCubic((t - tap) / 0.1));
      tipBoost = 1 - clamp01((t - tap) / 0.2);
      fireAge = double.infinity;
    } else if (t - tapFire >= 0 && t - tapFire < fireAge) {
      fireAge = t - tapFire;
    }
    final firing = fireAge < _flash;
    // Firing empties the membrane, unless a signal arrived since.
    if (fireAge < _comet && fireAge <= since) fill = 0;

    final x = ctx.x[out], y = ctx.y[out], radius = ctx.r[out];
    final track = radius + _gap;
    final frame = ctx.frame;

    // Ticks: one per arrival needed to fire.
    final ticks = 0.2 * ma;
    if (ticks >= 0.08) {
      final bucket = frame.litBucket(LineHue.structure, ticks);
      for (var k = 0; k < per; k++) {
        final angle = -math.pi / 2 + 2 * math.pi * k / per;
        final c = math.cos(angle), s = math.sin(angle);
        bucket.add(
          x + c * (track - 2),
          y + s * (track - 2),
          x + c * (track + 2.5),
          y + s * (track + 2.5),
        );
      }
    }

    // The membrane: violet while charging, cyan for the instant it fires.
    if (firing) {
      _arc(frame, LineHue.signal, 0.55 * ma, x, y, track, 1);
    } else if (fill > 0.004) {
      _arc(frame, LineHue.structure, 0.55 * ma, x, y, track, fill);
      final angle = -math.pi / 2 + 2 * math.pi * fill;
      frame.glow.add(
        Sprites.dot,
        x + track * math.cos(angle),
        y + track * math.sin(angle),
        5,
        ctx.colors.structure,
        (0.35 + 0.45 * tipBoost) * ma,
      );
    }

    // The output is a step function: dark until it fires, then fully on.
    final target = firing ? 1.0 : 0.04;
    ctx.actS[out] = lerp(ctx.actS[out], target, ma);
    ctx.actM[out] += 0.3 * fill * ma;

    if (fireAge < _comet) {
      final q = fireAge / _comet;
      // A ring leaves the membrane, and a spike runs down the axon.
      frame.cores.add(
        Sprites.ring,
        x,
        y,
        (track + 7 * easeOutCubic(q)) * 48 / 21,
        ctx.colors.signal,
        0.35 * (1 - q) * ma,
      );
      final axon = _axonLength(layout);
      if (axon > 8) {
        final x0 = x + track + 3;
        final head = x0 + (axon - 3) * easeOutCubic(q);
        final fade = (1 - q) * ma;
        final tail = math.min(16.0, head - x0);
        if (tail > 2) {
          frame.glow.add(
            Sprites.streakFor(tail),
            head - tail / 2,
            y,
            tail,
            ctx.colors.signal,
            0.6 * fade,
          );
        }
        frame.glow.add(
          Sprites.dot,
          head,
          y,
          0.8 * layout.r + 2.5,
          ctx.colors.signal,
          0.9 * fade,
        );
      }
    }
  }

  /// Scratch outputs of [_arrivals]: seconds since the latest arrival, and
  /// arrivals per second.
  static double _scratchSince = double.infinity, _scratchRate = 0;

  /// Signals that have reached the output at flow distance [flow], over the
  /// slots visible now. Mirrors the slot formulas of `VizScene._signals`.
  static int _arrivals(FrameContext ctx, double flow) {
    final layout = ctx.layout;
    final seed = layout.topology.seed;
    final factor = switch (ctx.quality) {
      VizQuality.low => 0.35,
      VizQuality.medium => 0.6,
      _ => 1.0,
    };
    final size = layout.size;
    final cap =
        ((size.width * size.height / 2600).round().clamp(24, 140) * factor)
            .round();
    final nMax = math.min(cap, 4 + (0.6 * layout.edgeCount).round());
    // x^0.85 without math.pow, which returns a boxed num.
    final x = clamp01(ctx.energy + 0.25 * ctx.heat);
    final drive = x <= 0 ? 0.0 : math.exp(0.85 * math.log(x));
    final active = 3 + (nMax - 3) * drive;
    final g = (layout.layerCount - 1).toDouble();
    final cycle = g / 0.8;
    final speed = EnergyTrack.speed(ctx.energy);
    final slots = math.min(140, active.ceil());
    var count = 0;
    var since = double.infinity, rate = 0.0;
    for (var k = 0; k < slots; k++) {
      if (smoothstep(0, 1, active - k) < 0.5) continue;
      final m = 0.85 + 0.3 * hash01(seed, k, 1);
      rate += m * speed / cycle;
      final phase = flow * m + hash01(seed, k, 2) * cycle;
      if (phase < g) continue;
      final cycles = ((phase - g) / cycle).floor();
      count += cycles + 1;
      final ago = (phase - g - cycles * cycle) / (m * speed);
      if (ago < since) since = ago;
    }
    _scratchSince = since;
    _scratchRate = rate;
    return count;
  }

  /// A clockwise arc from 12 o'clock covering [fill] of the circle.
  static void _arc(
    FrameBuffers frame,
    LineHue hue,
    double alpha,
    double x,
    double y,
    double radius,
    double fill,
  ) {
    if (alpha < 0.08) return;
    final bucket = frame.litBucket(hue, alpha);
    final segments = math.max(1, (24 * fill).ceil());
    final sweep = 2 * math.pi * fill;
    var px = x, py = y - radius;
    for (var i = 1; i <= segments; i++) {
      final angle = -math.pi / 2 + sweep * i / segments;
      final nx = x + radius * math.cos(angle),
          ny = y + radius * math.sin(angle);
      bucket.add(px, py, nx, ny);
      px = nx;
      py = ny;
    }
  }
}
