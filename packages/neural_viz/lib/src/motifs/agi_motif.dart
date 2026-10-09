import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../api/network_kind.dart';
import '../api/viz_types.dart';
import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/frame_buffers.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';
import '../scene/tap_tracker.dart';

/// AGI `[10,12,14,12,10]`: tilted counter-rotating rings (laid out and
/// rewired by the scene) around a breathing core.
///
/// - The core: a slow violet breath, a pink rim and a hot cyan center, with
///   faint spokes to the input ring.
/// - Signal hue ramps across the rings, cyan → violet → pink, for heads,
///   trails, hot cores, forward flares and the static ring guides.
/// - A tap: the core flashes, and when the forward wave reaches the outer
///   ring a violet ellipse expands past the frame.
class AgiMotif extends Motif {
  const AgiMotif();

  /// Unit circle, tessellated once. The core rim uses every 2nd or 4th
  /// point; the tap ellipse uses all of them so it stays round when it is
  /// larger than the view.
  static const _segments = 96;

  // Ring geometry of the frame being evaluated (static scratch: `Rect.center`
  // would allocate an Offset per call).
  static double _cx = 0, _cy = 0, _inner = 0, _outer = 1;

  static final Float32List _cos = _circle(math.cos);
  static final Float32List _sin = _circle(math.sin);

  static Float32List _circle(double Function(double) f) {
    final table = Float32List(_segments + 1);
    for (var i = 0; i <= _segments; i++) {
      table[i] = f(2 * math.pi * i / _segments);
    }
    return table;
  }

  static double get _heroSeconds =>
      NetworkKind.agi.heroTime.inMicroseconds / 1e6;

  /// Position across the rings, 0 at the input ring and 1 at the outer one,
  /// of a point in the (squashed) ring plane.
  static double _ringPosition(double x, double y) {
    final dx = x - _cx, dy = (y - _cy) / kRingSquash;
    if (_outer <= _inner) return 0;
    return clamp01((math.sqrt(dx * dx + dy * dy) - _inner) / (_outer - _inner));
  }

  /// The ring ramp: cyan → violet → pink.
  static int _rampRgb(SceneColors colors, double f) => f < 0.5
      ? _mixRgb(colors.signal, colors.structure, f / 0.5)
      : _mixRgb(colors.structure, colors.accent, (f - 0.5) / 0.5);

  static Color _rampColor(StaticContext ctx, double f) {
    final theme = ctx.theme;
    return f < 0.5
        ? Color.lerp(theme.signal, theme.structure, f / 0.5)!
        : Color.lerp(theme.structure, theme.accent, (f - 0.5) / 0.5)!;
  }

  // ---------------------------------------------------------------- static

  @override
  void paintOver(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (!layout.isRings || layout.ringRadius.isEmpty) return;
    // Tint the ring guides along the hue ramp; the outer ring is the
    // clearest (it carries the pink).
    final last = layout.layerCount - 1;
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 0; k <= last; k++) {
      final f = last == 0 ? 0.0 : k / last;
      guide.color = _rampColor(ctx, f).withValues(
        alpha: (k == last ? 0.16 : 0.08) * (ctx.highContrast ? 1.5 : 1),
      );
      final rx = layout.ringRadius[k];
      canvas.drawOval(
        Rect.fromCenter(
          center: layout.center,
          width: 2 * rx,
          height: 2 * rx * kRingSquash,
        ),
        guide,
      );
    }
  }

  // ------------------------------------------------------------ per frame

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    if (!layout.isRings || layout.ringRadius.isEmpty) return;
    final alpha = ctx.motifAlpha;
    if (alpha <= 0) return;
    final content = layout.content;
    _cx = content.left + content.width / 2;
    _cy = content.top + content.height / 2;
    _inner = layout.ringRadius[0];
    _outer = layout.ringRadius[layout.layerCount - 1];
    _tintSignals(ctx, alpha);
    _tintFlares(ctx, alpha);
    _ringCores(ctx, alpha);
    _spokes(ctx, alpha);
    _core(ctx, alpha);
    if (!ctx.reducedMotion) _tapEllipses(ctx, alpha);
  }

  /// The breathing core at the center of the rings.
  void _core(FrameContext ctx, double alpha) {
    final layout = ctx.layout;
    final frame = ctx.frame;
    final colors = ctx.colors;
    final rMax = layout.ringRadius[layout.layerCount - 1];
    final core = layout.coreRadius;
    final t = ctx.reducedMotion ? _heroSeconds : ctx.t;
    final breath = math.sin(2 * math.pi * t / 5);
    final e = ctx.energy;

    // A tap's forward front leaves the core; backprop comes back to it.
    var forward = 0.0, backward = 0.0;
    if (!ctx.reducedMotion) {
      final gaps = layout.layerCount + 1;
      final taps = ctx.taps;
      for (var w = 0; w < TapTracker.maxWaves; w++) {
        final age = ctx.t - taps.waveStart[w];
        if (age < 0 || age >= TapTracker.waveLife) continue;
        final amp = taps.waveAmp[w];
        if (age < 0.42) {
          forward += amp * gauss(gaps * easeInOutSine(age / 0.42), 0.45);
        }
        if (age >= 0.48 && age < 0.98) {
          final front = gaps * (1 - (age - 0.48) / 0.5);
          backward += 0.35 * amp * gauss(front, 0.45);
        }
      }
    }

    frame.glow.add(
      Sprites.glow,
      _cx,
      _cy,
      rMax,
      colors.structure,
      ((0.10 + 0.06 * breath) * (1 + 0.5 * e) + 0.45 * backward) * alpha,
    );
    final hot = clamp01(
      0.5 + 0.12 * breath + 0.25 * e + 0.3 * ctx.heat + 0.7 * forward,
    );
    if (ctx.quality != VizQuality.low) {
      frame.glow.add(
        Sprites.glow,
        _cx,
        _cy,
        2.4 * core,
        colors.signal,
        0.24 * hot * alpha,
      );
    }
    frame.cores.add(
      Sprites.dot,
      _cx,
      _cy,
      math.max(6.0, 0.36 * core),
      colors.signal,
      hot * alpha,
    );

    // Pink rim.
    final rim = 0.6 * alpha;
    if (rim >= 0.08) {
      _ellipseLines(
        frame.litBucket(LineHue.accent, rim),
        _cx,
        _cy,
        core,
        core,
        core > 40 ? 2 : 4, // 48 or 24 segments: long enough to stay smooth
      );
    }

    // A spark orbiting the rim, trailing a short streak.
    if (ctx.quality != VizQuality.low) {
      final angle = 2 * math.pi * t / 8;
      final ca = math.cos(angle), sa = math.sin(angle);
      final sx = _cx + core * ca, sy = _cy + core * sa;
      const trail = 14.0;
      frame.glow.add(
        Sprites.streakFor(trail),
        sx + sa * trail / 2,
        sy - ca * trail / 2,
        trail,
        colors.accent,
        0.7 * alpha,
        angle + math.pi / 2,
      );
      frame.cores.add(Sprites.dot, sx, sy, 5, colors.accent, 0.85 * alpha);
    }
  }

  /// Adds an ellipse as [_segments] lines, each shortened by the stroke's
  /// round caps so the joints don't double up under additive blending.
  static void _ellipseLines(
    LineBucket bucket,
    double cx,
    double cy,
    double rx,
    double ry,
    int step,
  ) {
    const cap = 0.6;
    for (var s = 0; s < _segments; s += step) {
      final x1 = cx + rx * _cos[s], y1 = cy + ry * _sin[s];
      final x2 = cx + rx * _cos[s + step], y2 = cy + ry * _sin[s + step];
      final dx = x2 - x1, dy = y2 - y1;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length <= 2 * cap) continue;
      final k = cap / length;
      bucket.add(x1 + dx * k, y1 + dy * k, x2 - dx * k, y2 - dy * k);
    }
  }

  /// Faint spokes from the core rim to the input ring: the routes signals
  /// take out of the core.
  void _spokes(FrameContext ctx, double alpha) {
    final layout = ctx.layout;
    final core = layout.coreRadius;
    for (var n = layout.layerStart[0]; n < layout.layerStart[1]; n++) {
      final dx = ctx.x[n] - _cx, dy = ctx.y[n] - _cy;
      final d = math.sqrt(dx * dx + dy * dy);
      final r = ctx.r[n];
      if (d <= core + r + 2) continue;
      final ux = dx / d, uy = dy / d;
      ctx.frame.addBaseEdge(
        _cx + ux * (core + 2),
        _cy + uy * (core + 2),
        ctx.x[n] - ux * r,
        ctx.y[n] - uy * r,
        false,
        0.13 * ctx.alpha[n] * alpha,
        false,
      );
    }
  }

  /// Hot cores (signal arrivals, predictions) in their ring's hue.
  void _ringCores(FrameContext ctx, double alpha) {
    final layout = ctx.layout;
    final last = layout.layerCount - 1;
    if (last <= 0) return;
    for (var k = 1; k <= last; k++) {
      final rgb = _rampRgb(ctx.colors, k / last);
      for (var n = layout.layerStart[k]; n < layout.layerStart[k + 1]; n++) {
        final s = clamp01(ctx.actS[n]);
        if (s <= 0.01) continue;
        ctx.frame.cores.add(
          Sprites.dot,
          ctx.x[n],
          ctx.y[n],
          1.1 * ctx.r[n] + 2,
          rgb,
          s * ctx.alpha[n] * alpha,
        );
        ctx.actS[n] *= 1 - alpha;
      }
    }
  }

  /// When a tap's forward front reaches the outer ring, a violet ellipse
  /// leaves the rings and expands past the frame over 900 ms.
  void _tapEllipses(FrameContext ctx, double alpha) {
    final layout = ctx.layout;
    final rings = layout.layerCount;
    final gaps = rings + 1;
    // The front reaches the outer ring (chain position `rings`) when
    // gaps·easeInOutSine(age / 0.42) = rings.
    final reach = 0.42 * math.acos(1 - 2 * rings / gaps) / math.pi;
    final outer = layout.ringRadius[rings - 1];
    final w = layout.size.width, h = layout.size.height;
    final far = math.max(
      _ellipseRadius(_cx, (_cy) / kRingSquash),
      math.max(
        _ellipseRadius(w - _cx, _cy / kRingSquash),
        math.max(
          _ellipseRadius(_cx, (h - _cy) / kRingSquash),
          _ellipseRadius(w - _cx, (h - _cy) / kRingSquash),
        ),
      ),
    );
    final end = 1.06 * far;
    final echo = ctx.quality == VizQuality.high;
    final taps = ctx.taps;
    for (var i = 0; i < TapTracker.maxWaves; i++) {
      final age = ctx.t - taps.waveStart[i] - reach;
      if (age < 0 || age >= 0.9) continue;
      final amp = math.min(1.0, taps.waveAmp[i]);
      final q = age / 0.9;
      _ellipse(
        ctx,
        lerp(outer, end, _easeOutQuad(q)),
        0.5 * (1 - q) * amp * alpha,
      );
      if (echo && q > 0.06) {
        final lag = q - 0.06;
        _ellipse(
          ctx,
          lerp(outer, end, _easeOutQuad(lag)),
          0.2 * (1 - lag) * amp * alpha,
        );
      }
    }
  }

  /// Gentler than a cubic, so the ellipse is still visibly leaving through
  /// the corners when it fades out.
  static double _easeOutQuad(double q) => 1 - (1 - q) * (1 - q);

  static double _ellipseRadius(double dx, double dy) =>
      math.sqrt(dx * dx + dy * dy);

  void _ellipse(FrameContext ctx, double rx, double alpha) {
    if (alpha < 0.06) return;
    _ellipseLines(
      ctx.frame.litBucket(LineHue.structure, alpha),
      _cx,
      _cy,
      rx,
      rx * kRingSquash,
      1,
    );
  }

  // ------------------------------------------------------------ ring hue

  /// Signal heads, trails and burst comets take the ring ramp hue of where
  /// they are.
  void _tintSignals(FrameContext ctx, double alpha) {
    final glow = ctx.frame.glow;
    final colors = ctx.colors;
    final signal = colors.signal;
    for (var i = 0; i < glow.count; i++) {
      final argb = glow.colors[i];
      if (argb & 0xffffff != signal) continue;
      final o = i * 4;
      final scos = glow.transforms[o], ssin = glow.transforms[o + 1];
      final ax = (glow.rects[o + 2] - glow.rects[o]) / 2;
      final ay = (glow.rects[o + 3] - glow.rects[o + 1]) / 2;
      final cx = glow.transforms[o + 2] + scos * ax - ssin * ay;
      final cy = glow.transforms[o + 3] + ssin * ax + scos * ay;
      final f = _ringPosition(cx, cy) * alpha;
      if (f <= 0.01) continue;
      glow.colors[i] = (((argb >> 24) & 0xff) << 24) | _rampRgb(colors, f);
    }
  }

  /// Forward-wave flares between the middle rings turn violet, between the
  /// outer rings pink.
  void _tintFlares(FrameContext ctx, double alpha) {
    if (alpha < 0.5) return;
    final frame = ctx.frame;
    final cyan = frame.lit[LineHue.signal.index];
    for (var level = 0; level < cyan.length; level++) {
      final bucket = cyan[level];
      final points = bucket.points;
      var kept = 0;
      for (var s = 0; s < bucket.count; s++) {
        final i = s * 4;
        final x1 = points[i], y1 = points[i + 1];
        final x2 = points[i + 2], y2 = points[i + 3];
        final f = _ringPosition((x1 + x2) / 2, (y1 + y2) / 2);
        if (f >= 0.3) {
          final hue = f < 0.7 ? LineHue.structure : LineHue.accent;
          frame.lit[hue.index][level].add(x1, y1, x2, y2);
          continue;
        }
        final k = kept * 4;
        points[k] = x1;
        points[k + 1] = y1;
        points[k + 2] = x2;
        points[k + 3] = y2;
        kept++;
      }
      bucket.count = kept;
    }
  }

  static int _mixRgb(int a, int b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final r =
        ((a >> 16) & 0xff) +
        ((((b >> 16) & 0xff) - ((a >> 16) & 0xff)) * t).round();
    final g =
        ((a >> 8) & 0xff) +
        ((((b >> 8) & 0xff) - ((a >> 8) & 0xff)) * t).round();
    final bl = (a & 0xff) + (((b & 0xff) - (a & 0xff)) * t).round();
    return (r << 16) | (g << 8) | bl;
  }
}
