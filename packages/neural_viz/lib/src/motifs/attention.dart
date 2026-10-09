import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../api/viz_types.dart';
import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/frame_buffers.dart';
import '../scene/hash.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';

// Shared pieces of the Transformer and LLM motifs: block plates, attention
// fans, residual skips, the autoregressive loop and the token stream.

/// Line segments per attention arc.
const _segments = 8;
const _points = _segments + 1;

/// Floats stored per arc in [AttentionGeometry.curve]: key point, control
/// point, query point, and the parameter range left after trimming the ends
/// at the neuron bodies.
const _curveStride = 8;

/// Ring sprites draw their circle at 21/48 of the sprite width.
const _ringWidthPerRadius = 48 / 21;

/// Geometry the attention motifs need, computed once per layout and cached
/// on the layout object.
class AttentionGeometry {
  AttentionGeometry._(this.layout)
    : blocks = math.max(0, layout.layerCount - 2),
      stride = _maxBlockSize(layout) {
    final arcs = blocks * stride * stride * 2;
    curve = Float32List(arcs * _curveStride);
    points = Float32List(arcs * _points * 2);
    plateLeft = Float32List(blocks);
    plateRight = Float32List(blocks);
    plateTop = Float32List(blocks);
    plateBottom = Float32List(blocks);
    weights = Float32List(stride);
    _buildPlates();
    _buildArcs();
    _buildLoop();
  }

  /// The geometry of [layout], built on first use.
  static AttentionGeometry of(NetworkLayout layout) =>
      _cache[layout] ??= AttentionGeometry._(layout);

  static final _cache = Expando<AttentionGeometry>('AttentionGeometry');

  final NetworkLayout layout;

  /// Attention blocks: every layer except the first and the last.
  final int blocks;

  /// Largest block size: arcs are indexed `(block, query, key, head)` with
  /// this stride.
  final int stride;

  /// Per arc: key x, y; control x, y; query x, y; s0, s1.
  late final Float32List curve;

  /// Per arc: [_points] tessellated points from the key to the query,
  /// trimmed at both neuron bodies.
  late final Float32List points;

  /// Block plate bounds.
  late final Float32List plateLeft, plateRight, plateTop, plateBottom;

  /// Scratch: attention weights of the head being evaluated.
  late final Float32List weights;

  /// The autoregressive loop (cubic, output column to input column).
  double loopX0 = 0, loopY0 = 0, loopX1 = 0, loopY1 = 0;
  double loopX2 = 0, loopY2 = 0, loopX3 = 0, loopY3 = 0;

  static int _maxBlockSize(NetworkLayout layout) {
    var n = 1;
    for (var l = 1; l < layout.layerCount - 1; l++) {
      n = math.max(n, layout.layerSize(l));
    }
    return n;
  }

  int arcIndex(int block, int query, int key, int head) =>
      ((block * stride + query) * stride + key) * 2 + head;

  void _buildPlates() {
    final r = layout.r;
    for (var b = 0; b < blocks; b++) {
      final l = b + 1;
      final first = layout.layerStart[l], last = layout.layerStart[l + 1] - 1;
      final x = layout.layerX[l];
      plateLeft[b] = x - r - 7;
      plateRight[b] = x + r + 7;
      plateTop[b] = layout.y[first] - layout.radius[first] - 7;
      plateBottom[b] = layout.y[last] + layout.radius[last] + 7;
    }
  }

  /// Quadratic arcs between every pair of a block's neurons: head A bulges
  /// left, head B right, by `0.35·|Δy| + 6` at the apex.
  void _buildArcs() {
    final maxBulge = 0.42 * layout.gap;
    for (var b = 0; b < blocks; b++) {
      final l = b + 1;
      final first = layout.layerStart[l], n = layout.layerSize(l);
      for (var q = 0; q < n; q++) {
        for (var j = 0; j < n; j++) {
          if (j == q) continue;
          final kx = layout.x[first + j], ky = layout.y[first + j];
          final qx = layout.x[first + q], qy = layout.y[first + q];
          final bulge = math.min(maxBulge, 0.35 * (qy - ky).abs() + 6);
          final trim = layout.radius[first + j] + 2.5;
          for (var head = 0; head < 2; head++) {
            final dir = head == 0 ? -1.0 : 1.0;
            // The apex of a quadratic sits halfway to its control point.
            final cx = (kx + qx) / 2 + dir * 2 * bulge;
            final cy = (ky + qy) / 2;
            final d0 = math.sqrt((cx - kx) * (cx - kx) + (cy - ky) * (cy - ky));
            final d2 = math.sqrt((qx - cx) * (qx - cx) + (qy - cy) * (qy - cy));
            final s0 = math.min(0.3, trim / (2 * d0));
            final s1 = math.max(0.7, 1 - trim / (2 * d2));
            final arc = arcIndex(b, q, j, head);
            final c = arc * _curveStride;
            curve
              ..[c] = kx
              ..[c + 1] = ky
              ..[c + 2] = cx
              ..[c + 3] = cy
              ..[c + 4] = qx
              ..[c + 5] = qy
              ..[c + 6] = s0
              ..[c + 7] = s1;
            final p = arc * _points * 2;
            for (var i = 0; i < _points; i++) {
              final s = lerp(s0, s1, i / _segments);
              final u = 1 - s;
              points[p + 2 * i] = u * u * kx + 2 * s * u * cx + s * s * qx;
              points[p + 2 * i + 1] = u * u * ky + 2 * s * u * cy + s * s * qy;
            }
          }
        }
      }
    }
  }

  /// A low arch from the top of the output column, over the blocks, down
  /// into the top of the input column.
  void _buildLoop() {
    final last = layout.layerCount - 1;
    final out = layout.layerStart[last];
    loopX0 = layout.layerX[last];
    loopY0 = layout.y[out] - layout.radius[out] - 6;
    loopX3 = layout.layerX[0];
    loopY3 = layout.y[0] - layout.radius[0] - 6;
    var top = math.min(loopY0, loopY3);
    for (var b = 0; b < blocks; b++) {
      top = math.min(top, plateTop[b] - 10);
    }
    // Halfway between the highest plate (and its depth copies) and the
    // top of the view.
    final apex = math.max(14.0, lerp(top - 6, 14, 0.45));
    final control = (8 * apex - loopY0 - loopY3) / 6;
    final inset = 0.12 * (loopX0 - loopX3);
    loopX1 = loopX0 - inset;
    loopY1 = control;
    loopX2 = loopX3 + inset;
    loopY2 = control;
  }

  /// Point on the autoregressive loop at [s] (0 at the output column).
  double loopX(double s) {
    final u = 1 - s;
    return u * u * u * loopX0 +
        3 * u * u * s * loopX1 +
        3 * u * s * s * loopX2 +
        s * s * s * loopX3;
  }

  double loopY(double s) {
    final u = 1 - s;
    return u * u * u * loopY0 +
        3 * u * u * s * loopY1 +
        3 * u * s * s * loopY2 +
        s * s * s * loopY3;
  }

  /// Direction of travel along the loop at [s], in radians.
  double loopAngle(double s) {
    final u = 1 - s;
    final dx =
        3 * u * u * (loopX1 - loopX0) +
        6 * u * s * (loopX2 - loopX1) +
        3 * s * s * (loopX3 - loopX2);
    final dy =
        3 * u * u * (loopY1 - loopY0) +
        6 * u * s * (loopY2 - loopY1) +
        3 * s * s * (loopY3 - loopY2);
    return math.atan2(dy, dx);
  }
}

// ---------------------------------------------------------------- static

/// Block plates under the attention layers. With [depth], each plate gets
/// two border-only copies stacked behind it (the LLM's "×96 blocks").
void paintPlates(
  Canvas canvas,
  StaticContext ctx,
  AttentionGeometry g, {
  bool depth = false,
}) {
  final theme = ctx.theme;
  final fill = Paint()..color = theme.surface.withValues(alpha: 0.55);
  final border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = theme.border;
  final bounds = Offset.zero & ctx.layout.size;
  for (var b = 0; b < g.blocks; b++) {
    final plate = RRect.fromLTRBR(
      g.plateLeft[b],
      g.plateTop[b],
      g.plateRight[b],
      g.plateBottom[b],
      const Radius.circular(6),
    );
    if (depth) {
      // Far copy first; each copy is hidden where a nearer plate covers it.
      final near = plate.shift(const Offset(5, -5));
      final far = plate.shift(const Offset(10, -10));
      // Violet at 45%, then 0.35 (near) and 0.18 (far).
      final copy = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas
        ..save()
        ..clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(bounds)
            ..addRRect(near)
            ..addRRect(plate),
        )
        ..drawRRect(
          far,
          copy..color = theme.structure.withValues(alpha: 0.18 * 0.45),
        )
        ..restore()
        ..save()
        ..clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(bounds)
            ..addRRect(plate),
        )
        ..drawRRect(
          near,
          copy..color = theme.structure.withValues(alpha: 0.35 * 0.45),
        )
        ..restore();
    }
    canvas
      ..drawRRect(plate, fill)
      ..drawRRect(plate, border);
  }
}

/// Residual skips (layer l → l + 2): faint violet arcs hanging below the
/// network and its captions.
void paintResiduals(Canvas canvas, StaticContext ctx, {double alpha = 0.25}) {
  final layout = ctx.layout;
  if (layout.layerCount < 3) return;
  var lowest = 0.0;
  for (var i = 0; i < layout.neuronCount; i++) {
    lowest = math.max(lowest, layout.y[i] + layout.radius[i]);
  }
  final top = layout.captions.isEmpty ? lowest + 9 : layout.captionY + 18;
  final floor = layout.size.height - 12;
  final depth = math.min(0.065 * layout.size.height, floor - top);
  if (depth < 7) return;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = true
    ..color = ctx.theme.structure.withValues(alpha: alpha);
  final path = Path();
  for (var l = 0; l + 2 < layout.layerCount; l++) {
    path
      ..moveTo(layout.layerX[l], top)
      ..quadraticBezierTo(
        layout.layerX[l + 1],
        top + 2 * depth,
        layout.layerX[l + 2],
        top,
      );
  }
  canvas.drawPath(path, stroke);
  final dot = Paint()
    ..color = ctx.theme.structure.withValues(alpha: math.min(1, 1.6 * alpha));
  for (var l = 0; l < layout.layerCount; l++) {
    canvas.drawCircle(Offset(layout.layerX[l], top), 1.5, dot);
  }
}

/// The autoregressive loop: a dashed violet arch from the output column
/// back to the input column, with a small arrowhead.
void paintLoop(Canvas canvas, StaticContext ctx, AttentionGeometry g) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true
    ..color = ctx.theme.structure.withValues(alpha: 0.22);
  final arch = Path()
    ..moveTo(g.loopX0, g.loopY0)
    ..cubicTo(g.loopX1, g.loopY1, g.loopX2, g.loopY2, g.loopX3, g.loopY3);
  final dashes = Path();
  for (final metric in arch.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += 11) {
      dashes.addPath(
        metric.extractPath(d, math.min(d + 6, metric.length)),
        Offset.zero,
      );
    }
  }
  canvas.drawPath(dashes, paint);
  // Arrowhead pointing into the input column.
  final angle = g.loopAngle(1);
  const length = 5.0, spread = 0.5;
  final head = Path();
  for (final side in const [-1.0, 1.0]) {
    final a = angle + math.pi + side * spread;
    head
      ..moveTo(g.loopX3, g.loopY3)
      ..lineTo(
        g.loopX3 + length * math.cos(a),
        g.loopY3 + length * math.sin(a),
      );
  }
  canvas.drawPath(
    head,
    paint..color = ctx.theme.structure.withValues(alpha: 0.4),
  );
}

// ------------------------------------------------------------- per frame

/// Attention cycles per second at energy [e]: a query every 2.4 s at rest,
/// every 1.2 s at full production.
double _attentionRate(double e) => (1 + e) / 2.4;

/// Attention phase (cycles since the start). Integrated from the energy
/// history so a change of production speeds the fans up without a jump:
/// `0.2604·v(E) + 0.1042` equals [_attentionRate], where `v(E)` is the
/// signal speed that `flow` integrates.
double _attentionPhase(FrameContext ctx, double heroTime) => ctx.reducedMotion
    ? heroTime * _attentionRate(ctx.energy)
    : 0.260417 * ctx.flow + 0.104167 * ctx.t;

/// Attention fans: in each block, a query lights up, both heads arc to its
/// keys with softmax weights, and the two strongest keys send a pulse back.
/// With [causal], a query only attends to the rows above it and the query
/// walks down the sequence one row per cycle. [locality] is how much nearby
/// keys are favored (logit penalty per row of distance).
void evaluateAttention(
  FrameContext ctx,
  AttentionGeometry g, {
  required bool causal,
  required double heroTime,
  double locality = 0.5,
}) {
  final fade = ctx.motifAlpha;
  if (g.blocks == 0 || fade <= 0.01) return;
  final layout = ctx.layout;
  final frame = ctx.frame;
  final seed = ctx.seed;
  final rate = _attentionRate(ctx.energy);
  final period = 1 / rate;
  final phase = _attentionPhase(ctx, heroTime);
  final temperature = 0.9 - 0.6 * ctx.contrast;
  final heads = ctx.quality == VizQuality.low ? 1 : 2;
  final pulses = ctx.quality != VizQuality.low;
  final marker = ctx.quality == VizQuality.high;
  final hold = 0.6 * period;
  final weights = g.weights;

  for (var b = 0; b < g.blocks; b++) {
    final l = b + 1;
    final first = layout.layerStart[l], n = layout.layerSize(l);
    if (n < 2 || (causal && n < 3)) continue;
    final pb = phase - b / 3;
    final cycle = pb.floorToDouble();
    final ts = (pb - cycle) * period;
    final rise = easeOutCubic(ts / 0.2);
    final fall = 1 - clamp01((ts - hold) / 0.4);
    if (fall <= 0) continue;
    final env = rise * fall * fade;

    final c = cycle.toInt();
    final int q;
    if (causal) {
      // Generation advances one position per cycle.
      final span = n - 2;
      q = 2 + (((c + 3) % span) + span) % span;
    } else {
      q = hash32(seed, 4432 + b, c & 0xffffff) % n;
    }
    final keyEnd = causal ? q : n;
    final query = first + q;

    // The query asks, then flashes when the strongest values arrive.
    var queryGlow = 0.3 * env;
    if (ts >= 0.7) queryGlow += 0.7 * math.exp(-(ts - 0.7) / 0.3) * fall * fade;
    ctx.actS[query] += queryGlow;
    if (marker) {
      final radius = ctx.r[query] + 4;
      frame.glow.add(
        Sprites.ring,
        ctx.x[query],
        ctx.y[query],
        radius * _ringWidthPerRadius,
        ctx.colors.signal,
        0.45 * env,
      );
    }

    for (var head = 0; head < heads; head++) {
      // Softmax over the keys; peakier as the model trains.
      var maxLogit = double.negativeInfinity;
      for (var j = 0; j < keyEnd; j++) {
        if (j == q) continue;
        final logit =
            (-locality * (q - j).abs() +
                1.2 * hash01(seed, 3100 + 2 * b + head, q, j)) /
            temperature;
        weights[j] = logit;
        if (logit > maxLogit) maxLogit = logit;
      }
      var sum = 0.0;
      for (var j = 0; j < keyEnd; j++) {
        if (j == q) continue;
        final w = math.exp(weights[j] - maxLogit);
        weights[j] = w;
        sum += w;
      }
      var best = -1, second = -1;
      for (var j = 0; j < keyEnd; j++) {
        if (j == q) continue;
        final w = weights[j] / sum;
        weights[j] = w;
        if (best < 0 || w > weights[best]) {
          second = best;
          best = j;
        } else if (second < 0 || w > weights[second]) {
          second = j;
        }
        ctx.actM[first + j] += 0.45 * w * env;
      }

      // Arcs grow out of the query towards its keys, then fade.
      final hue = head == 0 ? LineHue.signal : LineHue.structure;
      final start = (1 - rise) * _segments;
      final i0 = start.floor();
      for (var j = 0; j < keyEnd; j++) {
        if (j == q) continue;
        // Square root: the whole fan reads, the strongest keys stand out.
        final alpha = math.min(0.85, 1.1 * math.sqrt(weights[j])) * fall * fade;
        if (alpha < 0.13) continue;
        final bucket = frame.litBucket(hue, alpha);
        final p = g.arcIndex(b, q, j, head) * _points * 2;
        final pts = g.points;
        for (var i = i0; i < _segments; i++) {
          var ax = pts[p + 2 * i], ay = pts[p + 2 * i + 1];
          final bx = pts[p + 2 * i + 2], by = pts[p + 2 * i + 3];
          if (i == i0) {
            final f = start - i0;
            ax = lerp(ax, bx, f);
            ay = lerp(ay, by, f);
          }
          bucket.add(ax, ay, bx, by);
        }
      }

      // Values travel from the two strongest keys into the query.
      if (pulses && ts >= 0.2 && ts < 0.7) {
        final u = easeInOutSine((ts - 0.2) / 0.5);
        final rgb = head == 0 ? ctx.colors.signal : ctx.colors.structure;
        if (best >= 0) {
          _pulse(
            ctx,
            g,
            g.arcIndex(b, q, best, head),
            u,
            rgb,
            0.9 * fall * fade,
          );
        }
        if (second >= 0) {
          _pulse(
            ctx,
            g,
            g.arcIndex(b, q, second, head),
            u,
            rgb,
            0.55 * fall * fade,
          );
        }
      }
    }
  }
}

/// A dot with a short trail, a fraction [u] along an attention arc.
void _pulse(
  FrameContext ctx,
  AttentionGeometry g,
  int arc,
  double u,
  int rgb,
  double alpha,
) {
  final c = arc * _curveStride;
  final curve = g.curve;
  final kx = curve[c], ky = curve[c + 1];
  final cx = curve[c + 2], cy = curve[c + 3];
  final qx = curve[c + 4], qy = curve[c + 5];
  final s = lerp(curve[c + 6], curve[c + 7], u);
  final v = 1 - s;
  final x = v * v * kx + 2 * s * v * cx + s * s * qx;
  final y = v * v * ky + 2 * s * v * cy + s * s * qy;
  final dx = 2 * v * (cx - kx) + 2 * s * (qx - cx);
  final dy = 2 * v * (cy - ky) + 2 * s * (qy - cy);
  final angle = math.atan2(dy, dx);
  final r = ctx.layout.r;
  const trail = 12.0;
  ctx.frame.glow
    ..add(
      Sprites.streak12,
      x - trail / 2 * math.cos(angle),
      y - trail / 2 * math.sin(angle),
      trail,
      rgb,
      0.5 * alpha,
      angle,
    )
    ..add(Sprites.dot, x, y, 0.7 * r + 2.5, rgb, alpha);
}

// ---------------------------------------------------------------- tokens

/// Tokens per second at energy [e]: 0.7 at rest up to 8 at full production.
double _tokenRate(double e) => 0.7 + 7.3 * e;

/// Share of emission slots that carry a token (the rest are skipped, so
/// the stream is irregular like real generation).
const _slotFill = 0.85;
const _tokenLife = 1.2;
const _maxTokens = 12;
const _maxRiders = 3;
const _rideTime = 1.0;

/// Emission phase: `∫ rate dt / _slotFill`, integrated from the energy
/// history (`4.5625·v(E) − 4.775` is exactly `0.7 + 7.3·E`).
double _tokenPhase(FrameContext ctx, double heroTime) =>
    (ctx.reducedMotion
        ? heroTime * _tokenRate(ctx.energy)
        : 4.5625 * ctx.flow - 4.775 * ctx.t) /
    _slotFill;

/// The LLM's generated tokens: cyan pills drifting out of the logits into
/// the right margin, at a rate tied to production, plus one per training
/// tap at +420 ms. A few ride the autoregressive loop back to the input.
void evaluateTokens(
  FrameContext ctx,
  AttentionGeometry g, {
  required double heroTime,
}) {
  final fade = ctx.motifAlpha;
  if (fade <= 0.01) return;
  final layout = ctx.layout;
  final seed = ctx.seed;
  final last = layout.layerCount - 1;
  final firstOut = layout.layerStart[last], outs = layout.layerSize(last);
  final rate = _tokenRate(ctx.energy) / _slotFill;
  final phase = _tokenPhase(ctx, heroTime);
  final riders = ctx.quality != VizQuality.low;
  final riderChance = math.min(1.0, 1.4 / (rate * _slotFill));

  // A training tap emits a token as its prediction lands (+420 ms). Taps
  // while the network transforms run no wave, so they emit nothing.
  var alive = 0, riding = 0;
  if (!ctx.reducedMotion && fade >= 1) {
    final taps = ctx.taps;
    for (var i = 0; i < taps.waveStart.length; i++) {
      final age = ctx.t - taps.waveStart[i] - 0.42;
      if (age < 0 || age >= _tokenLife) continue;
      alive++;
      _token(ctx, ctx.predicted, age, math.min(1.0, taps.waveAmp[i]));
    }
  }

  final newest = phase.floor();
  final oldest = (phase - math.max(_tokenLife, _rideTime) * rate).floor() - 1;
  for (var k = newest; k >= oldest && k >= 0; k--) {
    if (hash01(seed, 4000, k) >= _slotFill) continue;
    final age = (phase - k - 0.6 * hash01(seed, 4001, k)) / rate;
    if (age < 0) continue;
    // Sampled: mostly the argmax once trained, anywhere before.
    final out = hash01(seed, 4002, k) < 0.25 + 0.35 * ctx.accuracy
        ? ctx.predicted
        : firstOut + hash32(seed, 4003, k) % outs;
    if (age < _tokenLife && alive < _maxTokens) {
      alive++;
      _token(ctx, out, age, fade);
    }
    if (riders &&
        age < _rideTime &&
        riding < _maxRiders &&
        hash01(seed, 4004, k) < riderChance) {
      riding++;
      _ride(ctx, g, age, fade);
    }
  }
}

void _token(FrameContext ctx, int out, double age, double fade) {
  final q = age / _tokenLife;
  final r = ctx.r[out];
  final x = ctx.x[out] + r + 10 + 40 * q;
  final y = ctx.y[out];
  final alpha = smoothstep(0, 0.08, age) * smoothstep(1, 0.45, q) * fade;
  final width = math.min(12.0, math.max(8.0, 1.3 * r + 1));
  ctx.frame.glow
    ..add(Sprites.glow, x, y, 2 * width, ctx.colors.signal, 0.2 * alpha)
    ..add(Sprites.pill, x, y, width, ctx.colors.signal, alpha);
  // The logit that produced it flashes as the token leaves.
  if (age < 0.25) ctx.actS[out] += 0.4 * (1 - age / 0.25) * fade;
}

/// A token riding the loop from the logits back to the input column.
void _ride(FrameContext ctx, AttentionGeometry g, double age, double fade) {
  final q = age / _rideTime;
  final s = easeInOutSine(q);
  final x = g.loopX(s), y = g.loopY(s);
  final angle = g.loopAngle(s);
  final alpha = smoothstep(0, 0.12, q) * smoothstep(1, 0.85, q) * fade;
  const trail = 14.0;
  ctx.frame.glow
    ..add(
      Sprites.streak12,
      x - trail / 2 * math.cos(angle),
      y - trail / 2 * math.sin(angle),
      trail,
      ctx.colors.signal,
      0.45 * alpha,
      angle,
    )
    ..add(Sprites.dot, x, y, 5, ctx.colors.signal, 0.8 * alpha);
  // Arriving at the input: the newest token joins the context.
  if (q > 0.9) {
    ctx.actS[ctx.layout.layerStart[0]] += 0.6 * (q - 0.9) / 0.1 * fade;
  }
}
