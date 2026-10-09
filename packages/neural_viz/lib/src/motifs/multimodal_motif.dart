import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../api/network_kind.dart';
import '../api/viz_types.dart';
import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/frame_buffers.dart';
import '../scene/hash.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';
import '../scene/tap_tracker.dart';

/// Multimodal `[8,10,12,10,8]`: text, image and audio inputs (circles,
/// squares, diamonds) run through their own encoder lanes and merge on a
/// soft violet fusion band.
///
/// - Static: the fusion band, modality rims on the inputs, a bracket and a
///   mono caption (`TXT`, `IMG`, `WAV`) per group.
/// - Per frame: a scrolling audio waveform, a modality glow on the inputs,
///   and every signal keeps its modality hue until it reaches fusion, where
///   it turns cyan. A tap fires all three groups at once.
class MultimodalMotif extends Motif {
  const MultimodalMotif();

  /// The layer where the modalities merge.
  static const fusionLayer = 2;

  static const _wavePoints = 24;
  static const _waveWidth = 30.0;

  /// Waveform samples scrolled per layer gap of signal travel, so the audio
  /// speeds up with production without ever jumping.
  static const _samplesPerGap = 7.0;

  // Scratch results of [_laneAt] (static: evaluate must not allocate).
  static double _u = 0;
  static int _pair = 0;

  // ------------------------------------------------------------- geometry

  /// Lane (0 text, 1 image, 2 audio) of neuron [n] of the input or encoder
  /// layer, matching the layout's split (8 → 3/3/2, 10 → 4/3/3); -1 when
  /// the network has no lanes.
  static int laneOf(NetworkLayout layout, int n) {
    final layer = layout.layerOf[n];
    if (layer > 1 || !_hasLanes(layout)) return -1;
    return _group(n - layout.layerStart[layer], layout.layerSize(layer));
  }

  static bool _hasLanes(NetworkLayout layout) =>
      layout.layerCount > fusionLayer &&
      layout.layerSize(0) >= 3 &&
      layout.layerSize(1) >= 3;

  static int _group(int i, int n) {
    final first = (n + 2) ~/ 3;
    final second = (n - first + 1) ~/ 2;
    return i < first ? 0 : (i < first + second ? 1 : 2);
  }

  /// Right edge of the input group brackets.
  static double _bracketX(NetworkLayout layout) =>
      layout.layerX[0] - 1.2 * layout.r - 5;

  static bool _hasWaveform(NetworkLayout layout) =>
      layout.size.width >= kCompactWidth;

  static Color _hue(StaticContext ctx, int lane) => switch (lane) {
    1 => ctx.theme.success,
    2 => ctx.theme.accent,
    _ => ctx.theme.signal,
  };

  static int _laneRgb(SceneColors colors, int lane) => switch (lane) {
    1 => colors.success,
    2 => colors.accent,
    _ => colors.signal,
  };

  // ---------------------------------------------------------------- static

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.layerCount <= fusionLayer) return;
    // A soft vertical light band behind the fusion column: a horizontal
    // gradient, faded in at both ends with thin strips (no saveLayer).
    final first = layout.layerStart[fusionLayer];
    final last = layout.layerStart[fusionLayer + 1] - 1;
    final cx = layout.layerX[fusionLayer];
    final half = math.min(0.5 * layout.gap, 72.0);
    final top = layout.y[first] - 2.4 * layout.pitch;
    final bottom = layout.captions.isEmpty
        ? layout.y[last] + 1.8 * layout.pitch
        : layout.captionY + 18;
    final fade = math.min(2.2 * layout.pitch, (bottom - top) / 3);
    final peak = ctx.highContrast ? 0.10 : 0.08;
    const profile = [0.0, 0.28, 0.72, 1.0, 0.72, 0.28, 0.0];
    const stops = [0.0, 1 / 6, 2 / 6, 0.5, 4 / 6, 5 / 6, 1.0];
    Paint band(double k) => Paint()
      ..isAntiAlias = false
      ..shader = ui.Gradient.linear(
        Offset(cx - half, 0),
        Offset(cx + half, 0),
        [
          for (final p in profile)
            ctx.theme.structure.withValues(alpha: peak * p * k),
        ],
        stops,
      );
    canvas.drawRect(
      Rect.fromLTRB(cx - half, top + fade, cx + half, bottom - fade),
      band(1),
    );
    const strips = 16;
    final h = fade / strips;
    for (var s = 0; s < strips; s++) {
      final paint = band(smoothstep(0, 1, (s + 0.5) / strips));
      canvas
        ..drawRect(
          Rect.fromLTRB(cx - half, top + s * h, cx + half, top + (s + 1) * h),
          paint,
        )
        ..drawRect(
          Rect.fromLTRB(
            cx - half,
            bottom - (s + 1) * h,
            cx + half,
            bottom - s * h,
          ),
          paint,
        );
    }
  }

  @override
  void paintOver(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (!_hasLanes(layout)) return;
    final theme = ctx.theme;
    final rimWidth = ctx.highContrast ? 1.75 : 1.25;

    // Modality rims over the input bodies.
    final fill = Paint();
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth;
    for (var n = layout.layerStart[0]; n < layout.layerStart[1]; n++) {
      final hue = _hue(ctx, laneOf(layout, n));
      fill.color = hue.withValues(alpha: 0.06);
      rim.color = hue.withValues(alpha: 0.6);
      final x = layout.x[n], y = layout.y[n], r = layout.radius[n];
      switch (NeuronShape.values[layout.shape[n]]) {
        case NeuronShape.circle:
          canvas
            ..drawCircle(Offset(x, y), r, fill)
            ..drawCircle(Offset(x, y), r, rim);
        case NeuronShape.square:
          final rect = RRect.fromLTRBR(
            x - r,
            y - r,
            x + r,
            y + r,
            Radius.circular(r * 0.5),
          );
          canvas
            ..drawRRect(rect, fill)
            ..drawRRect(rect, rim);
        case NeuronShape.diamond:
          final d = r * 1.2;
          final path = Path()
            ..moveTo(x, y - d)
            ..lineTo(x + d, y)
            ..lineTo(x, y + d)
            ..lineTo(x - d, y)
            ..close();
          canvas
            ..drawPath(path, fill)
            ..drawPath(path, rim);
      }
    }

    // A thin bracket left of each group, with its caption.
    final bracket = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
    final bx = _bracketX(layout);
    final captionRight = _hasWaveform(layout)
        ? bx - 4 - _waveWidth - 7
        : bx - 6;
    final style = TextStyle(
      fontFamily: theme.monoFontFamily,
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: ctx.highContrast ? theme.textSecondary : theme.textMuted,
    );
    for (var lane = 0; lane < 3; lane++) {
      var top = double.infinity, bottom = double.negativeInfinity;
      for (var n = layout.layerStart[0]; n < layout.layerStart[1]; n++) {
        if (laneOf(layout, n) != lane) continue;
        top = math.min(top, layout.y[n]);
        bottom = math.max(bottom, layout.y[n]);
      }
      if (top > bottom) continue;
      final y0 = top - 0.9 * layout.r, y1 = bottom + 0.9 * layout.r;
      bracket.color = _hue(ctx, lane).withValues(alpha: 0.32);
      canvas
        ..drawLine(Offset(bx, y0), Offset(bx, y1), bracket)
        ..drawLine(Offset(bx, y0), Offset(bx + 3, y0), bracket)
        ..drawLine(Offset(bx, y1), Offset(bx + 3, y1), bracket);

      if (layout.captions.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: const ['TXT', 'IMG', 'WAV'][lane], style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          captionRight - painter.width,
          (top + bottom) / 2 - painter.height / 2,
        ),
      );
      painter.dispose();
    }
  }

  // ------------------------------------------------------------ per frame

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    if (!_hasLanes(layout)) return;
    final alpha = ctx.motifAlpha;
    if (alpha <= 0) return;

    _tintSignals(ctx, alpha);
    _tintFlares(ctx, alpha);

    // Training taps fire the three groups together.
    var burst = 0.0, loud = 0.0;
    if (!ctx.reducedMotion) {
      final taps = ctx.taps;
      for (var w = 0; w < TapTracker.maxWaves; w++) {
        final age = ctx.t - taps.waveStart[w];
        if (age < 0 || age >= 0.6) continue;
        final amp = math.min(1.0, taps.waveAmp[w]);
        if (age < 0.35) {
          final q = 1 - age / 0.35;
          burst += amp * q * q;
        }
        loud += amp * (1 - age / 0.6);
      }
    }
    _inputs(ctx, alpha, math.min(1.0, burst));
    if (_hasWaveform(layout)) {
      _waveform(
        ctx,
        alpha,
        clamp01(0.3 + 0.55 * ctx.energy + 0.4 * ctx.heat + 0.7 * loud),
      );
    }
  }

  /// Input glows in the modality hue, the group burst on taps, and the hot
  /// cores of the input and encoder layers re-emitted in their lane's hue.
  void _inputs(FrameContext ctx, double alpha, double burst) {
    final layout = ctx.layout;
    final frame = ctx.frame;
    final colors = ctx.colors;
    final low = ctx.quality == VizQuality.low;
    final base = 0.06 + 0.10 * ctx.energy + 0.16 * ctx.heat;
    for (var n = layout.layerStart[0]; n < layout.layerStart[2]; n++) {
      final lane = laneOf(layout, n);
      final rgb = _laneRgb(colors, lane);
      final a = ctx.alpha[n] * alpha;
      if (layout.layerOf[n] == 0 && !low) {
        frame.glow.add(
          Sprites.glow,
          ctx.x[n],
          ctx.y[n],
          5 * ctx.r[n],
          rgb,
          math.min(0.8, base + 0.5 * burst) * a,
        );
      }
      if (lane <= 0) continue; // text is already cyan
      final s = clamp01(ctx.actS[n]);
      if (s <= 0.01) continue;
      frame.cores.add(
        Sprites.dot,
        ctx.x[n],
        ctx.y[n],
        1.1 * ctx.r[n] + 2,
        rgb,
        s * a,
      );
      ctx.actS[n] *= 1 - alpha;
    }
    if (burst <= 0.01) return;
    // One soft bloom per group, all three at once.
    for (var lane = 0; lane < 3; lane++) {
      var top = double.infinity, bottom = double.negativeInfinity;
      for (var n = layout.layerStart[0]; n < layout.layerStart[1]; n++) {
        if (laneOf(layout, n) != lane) continue;
        top = math.min(top, ctx.y[n]);
        bottom = math.max(bottom, ctx.y[n]);
      }
      if (top > bottom) continue;
      final rgb = _laneRgb(colors, lane);
      frame.glow.add(
        Sprites.glow,
        layout.layerX[0],
        (top + bottom) / 2,
        (bottom - top) * 1.4 + 8 * layout.r,
        rgb,
        0.22 * burst * alpha,
      );
      final bx = _bracketX(layout);
      final y0 = top - 0.9 * layout.r, y1 = bottom + 0.9 * layout.r;
      final hue = switch (lane) {
        1 => LineHue.success,
        2 => LineHue.accent,
        _ => LineHue.signal,
      };
      if (burst * alpha > 0.12) {
        frame.litBucket(hue, 0.7 * burst * alpha).add(bx, y0, bx, y1);
      }
    }
  }

  /// A 24-point audio waveform scrolling into the audio group.
  void _waveform(FrameContext ctx, double alpha, double loudness) {
    final layout = ctx.layout;
    var top = double.infinity, bottom = double.negativeInfinity;
    for (var n = layout.layerStart[0]; n < layout.layerStart[1]; n++) {
      if (laneOf(layout, n) != 2) continue;
      top = math.min(top, ctx.y[n]);
      bottom = math.max(bottom, ctx.y[n]);
    }
    if (top > bottom) return;
    final x1 = _bracketX(layout) - 4, x0 = x1 - _waveWidth;
    final cy = (top + bottom) / 2;
    final amplitude = (0.5 * (bottom - top) + 0.7 * layout.r) * loudness;
    final flow = ctx.reducedMotion
        ? NetworkKind.multimodal.heroTime.inMicroseconds / 1e6 * 1.6
        : ctx.flow;
    final tau = flow * _samplesPerGap;
    final head = tau.floorToDouble();
    final fr = tau - head;
    final dx = (x1 - x0) / (_wavePoints - 1);
    final seed = ctx.seed;
    var px = 0.0, py = 0.0;
    for (var j = -1; j < _wavePoints; j++) {
      final x = x0 + (fr + j) * dx;
      final y = cy - amplitude * _sample(seed, head.toInt() - j);
      if (j >= 0) {
        var ax = px, ay = py, bx = x, by = y;
        if (bx > x0 && ax < x1) {
          if (ax < x0) {
            ay += (by - ay) * (x0 - ax) / (bx - ax);
            ax = x0;
          }
          if (bx > x1) {
            by = ay + (by - ay) * (x1 - ax) / (bx - ax);
            bx = x1;
          }
          final q = ((ax + bx) / 2 - x0) / (x1 - x0);
          final a = 0.6 * smoothstep(0, 0.45, q) * alpha;
          if (a > 0.06) {
            ctx.frame.litBucket(LineHue.accent, a).add(ax, ay, bx, by);
          }
        }
      }
      px = x;
      py = y;
    }
  }

  /// Audio sample [k] in -1..1: a two-tone carrier under a syllable-like
  /// envelope, fixed per sample so the line scrolls rigidly.
  static double _sample(int seed, int k) {
    final carrier = 0.65 * math.sin(k * 1.31) + 0.35 * math.sin(k * 2.77 + 0.9);
    final s = k / 6.0;
    final i = s.floor();
    final env = lerp(
      hash01(seed, 7100, i),
      hash01(seed, 7100, i + 1),
      smoothstep(0, 1, s - i),
    );
    return carrier * (0.12 + 0.88 * env * env);
  }

  // ------------------------------------------------------------ modality hue

  /// Lane of the encoder edge passing through (px, py), or -1 outside the
  /// encoders. Sets [_pair] (0 input → encoder, 1 encoder → fusion) and
  /// [_u], the position along that edge.
  static int _laneAt(FrameContext ctx, double px, double py) {
    final layout = ctx.layout;
    final xa = layout.layerX[0], xb = layout.layerX[1];
    final xc = layout.layerX[fusionLayer];
    if (px < xa - 0.5 || px >= xc) return -1;
    final pair = px <= xb ? 0 : 1;
    final from = pair == 0 ? xa : xb, to = pair == 0 ? xb : xc;
    final u = to > from ? clamp01((px - from) / (to - from)) : 0.0;
    var best = double.infinity;
    var lane = -1;
    for (
      var s = layout.layerStart[pair];
      s < layout.layerStart[pair + 1];
      s++
    ) {
      final ys = ctx.y[s];
      for (var o = layout.outStart[s]; o < layout.outStart[s + 1]; o++) {
        final d = layout.edgeDst[layout.outEdges[o]];
        final error = (ys + (ctx.y[d] - ys) * u - py).abs();
        if (error < best) {
          best = error;
          lane = laneOf(layout, s);
        }
      }
    }
    _pair = pair;
    _u = u;
    return best < 2 * layout.r ? lane : -1;
  }

  /// Gives every cyan sprite inside the encoder lanes (signal heads, trails,
  /// burst comets, input ripples) its modality hue, easing back to cyan as
  /// it reaches the fusion layer.
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
      final lane = _laneAt(ctx, cx, cy);
      if (lane <= 0) continue;
      var mix = alpha;
      if (_pair == 1) mix *= 1 - smoothstep(0.55, 1, _u);
      if (mix <= 0.01) continue;
      final rgb = _mixRgb(signal, _laneRgb(colors, lane), mix);
      glow.colors[i] = (((argb >> 24) & 0xff) << 24) | rgb;
    }
  }

  /// Moves forward-wave flares inside the image and audio lanes from the
  /// cyan buckets to the lime and pink ones.
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
        final lane = _laneAt(ctx, (x1 + x2) / 2, (y1 + y2) / 2);
        if (lane > 0 && (_pair == 0 || _u < 0.8)) {
          final hue = lane == 1 ? LineHue.success : LineHue.accent;
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
