import 'dart:math' as math;
import 'dart:ui';

import '../render/sprite_atlas.dart';
import '../scene/easing.dart';
import '../scene/frame_buffers.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';

/// A convolutional network scanning a tiny image.
///
/// Static: a panel under each convolutional column and a frame for the
/// input thumbnail.
///
/// Per frame: a violet kernel bracket steps down the input column (faster
/// with production); its receptive-field edges flare cyan into the target
/// feature, which lights up by how much ink the window covers. A slower
/// bracket does the same on the next layer. On wide views a 6×6 one-bit
/// image (a cat, a dog, a bird) sits left of the inputs, each pixel row
/// feeding one input cell, with a 3×3 window scanning it in step with the
/// bracket.
class CnnMotif extends Motif {
  const CnnMotif();

  /// Kernel steps per layer gap of signal flow (≈ 360 ms per step at rest,
  /// ≈ 160 ms at full production).
  static const _stepsPerGap = 2.3;

  /// Thumbnail pixel pitch: 5 px, 6 px when there is room.
  static double _pixel(NetworkLayout layout) =>
      layout.size.width >= 600 ? 6 : 5;

  /// The input images, one 6-bit row per entry (bit 5 is the left pixel).
  static const _glyphs = [
    // Cat: pointed ears, eyes.
    0x21, 0x33, 0x3f, 0x2d, 0x3f, 0x1e,
    // Dog, in profile: ear, head, body, legs.
    0x02, 0x27, 0x1e, 0x1e, 0x12, 0x12,
    // Bird, wings up.
    0x00, 0x21, 0x33, 0x1e, 0x0c, 0x00,
  ];

  // ------------------------------------------------------------- static

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    final layout = ctx.layout;
    if (layout.isRings) return;
    final fill = Paint()..color = ctx.theme.surface.withValues(alpha: 0.6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ctx.theme.border;
    final pad = 0.55 * layout.r + 4;
    for (var l = 0; l < math.min(3, layout.layerCount - 1); l++) {
      final first = layout.layerStart[l], last = layout.layerStart[l + 1] - 1;
      final r = layout.radius[first];
      final rect = RRect.fromLTRBR(
        layout.layerX[l] - r - pad,
        layout.y[first] - r - pad,
        layout.layerX[l] + r + pad,
        layout.y[last] + r + pad,
        const Radius.circular(6),
      );
      canvas
        ..drawRRect(rect, fill)
        ..drawRRect(rect, stroke);
    }
    final left = _thumbLeft(layout);
    if (!left.isNaN) {
      final top = _thumbTop(layout);
      final px = _pixel(layout);
      final rect = RRect.fromLTRBR(
        left - 4,
        top - 4,
        left + 6 * px + 4,
        top + 6 * px + 4,
        const Radius.circular(4),
      );
      canvas
        ..drawRRect(rect, fill)
        ..drawRRect(rect, stroke);
    }
  }

  /// Left edge of the 6×6 thumbnail, or NaN when it isn't shown.
  static double _thumbLeft(NetworkLayout layout) {
    if (layout.size.width < kCompactWidth ||
        layout.layerCount < 3 ||
        layout.layerSize(0) != 6) {
      return double.nan;
    }
    final first = layout.layerStart[0];
    final pad = 0.55 * layout.r + 4;
    final right = layout.layerX[0] - layout.radius[first] - pad - 16;
    final left = (right - 6 * _pixel(layout)).roundToDouble();
    return left < 12 ? double.nan : left;
  }

  /// Top edge of the thumbnail: centered on the input column.
  static double _thumbTop(NetworkLayout layout) {
    final first = layout.layerStart[0];
    final cy = 0.5 * (layout.y[first] + layout.y[first + 5]);
    return (cy - 3 * _pixel(layout)).roundToDouble();
  }

  // ---------------------------------------------------------- per frame

  @override
  void evaluate(FrameContext ctx) {
    final layout = ctx.layout;
    final ma = ctx.motifAlpha;
    if (layout.isRings || ma <= 0 || layout.layerCount < 3) return;
    final phase = ctx.flow * _stepsPerGap;

    final density = _kernel(ctx, 0, phase, true);
    if (layout.layerCount >= 4) _kernel(ctx, 1, phase / 3, false);
    _image(ctx, phase, density);
  }

  /// Center (source index) of target [j]'s receptive field.
  static int _center(int j, int src, int dst) =>
      dst <= 1 ? (src - 1) ~/ 2 : (j * (src - 1) / (dst - 1)).round();

  /// Vertical position of fractional source index [f] in layer [l].
  static double _yAt(FrameContext ctx, int l, double f) {
    final layout = ctx.layout;
    final first = layout.layerStart[l], n = layout.layerSize(l);
    if (n < 2) return ctx.y[first];
    final pitch = (ctx.y[first + n - 1] - ctx.y[first]) / (n - 1);
    return ctx.y[first] + f * pitch;
  }

  /// Draws the bracket stepping down layer [l] and its flares into layer
  /// l + 1. Returns the ink density under the input window (first kernel).
  static double _kernel(FrameContext ctx, int l, double phase, bool image) {
    final layout = ctx.layout;
    final ma = ctx.motifAlpha;
    final src = layout.layerSize(l), dst = layout.layerSize(l + 1);
    if (src < 2 || dst < 1) return 0;
    final step = phase.floor();
    final frac = phase - step;
    final j = step % dst, before = (step - 1) % dst;
    final glide = easeInOutCubic(clamp01(frac / 0.4));
    final c0 = _center(before, src, dst), c1 = _center(j, src, dst);
    final center = lerp(c0.toDouble(), c1.toDouble(), glide);

    final first = layout.layerStart[l];
    final r = ctx.r[first];
    final x = ctx.x[first];
    final top = _yAt(ctx, l, center - 1) - r - 3;
    final bottom = _yAt(ctx, l, center + 1) + r + 3;
    final bracketAlpha = (image ? 0.6 : 0.4) * ma;
    if (bracketAlpha >= 0.08) {
      final bucket = ctx.frame.litBucket(LineHue.structure, bracketAlpha);
      final inner = math.min(5.0, 0.6 * r + 1);
      for (var side = -1; side <= 1; side += 2) {
        final bx = x + side * (r + 4.5);
        final tx = bx - side * inner, cx = bx - side * 1.5;
        bucket
          ..add(tx, top, cx, top)
          ..add(cx, top, bx, top + 1.5)
          ..add(bx, top + 1.5, bx, bottom - 1.5)
          ..add(bx, bottom - 1.5, cx, bottom)
          ..add(cx, bottom, tx, bottom);
      }
    }

    // Ink under the input window drives how strongly the feature fires.
    var density = 0.55;
    if (image) density = _windowDensity(ctx, phase, c1);

    // The sources under the bracket are being read.
    for (var i = c1 - 1; i <= c1 + 1; i++) {
      if (i < 0 || i >= src || glide < 1) continue;
      ctx.actS[first + i] += 0.12 * ma;
    }

    // Receptive-field edges flare into the target once the bracket lands.
    final target = layout.layerStart[l + 1] + j;
    final u = (frac - 0.3) / 0.55;
    final flare = (image ? 0.55 : 0.32) * (0.6 + 0.4 * density) * ma;
    if (u > 0 && u < 1.35 && flare >= 0.08) {
      final bucket = ctx.frame.litBucket(LineHue.signal, flare);
      final lo = clamp01(u - 0.35), hi = clamp01(u);
      for (var i = c1 - 1; i <= c1 + 1; i++) {
        if (i < 0 || i >= src) continue;
        final s = first + i;
        for (var k = layout.outStart[s]; k < layout.outStart[s + 1]; k++) {
          final e = layout.outEdges[k];
          if (layout.edgeDst[e] != target) continue;
          final dx = ctx.x[target] - ctx.x[s], dy = ctx.y[target] - ctx.y[s];
          if (hi > lo) {
            bucket.add(
              ctx.x[s] + dx * lo,
              ctx.y[s] + dy * lo,
              ctx.x[s] + dx * hi,
              ctx.y[s] + dy * hi,
            );
          }
        }
      }
    }

    // The target feature lights as the flare lands and hands over to the
    // next one.
    final hit = (image ? 0.75 : 0.5) * (0.35 + 0.65 * density) * ma;
    ctx.actS[target] += hit * smoothstep(0.62, 0.85, frac);
    final previous = layout.layerStart[l + 1] + before;
    ctx.actS[previous] += hit * (1 - smoothstep(0, 0.7, frac));
    return density;
  }

  /// Fraction of lit pixels in the 3×3 window for target row [row].
  static double _windowDensity(FrameContext ctx, double phase, int row) {
    final layout = ctx.layout;
    if (layout.layerSize(0) != 6) return 0.55;
    final dst = layout.layerSize(1);
    final pass = (phase.floor() / dst).floor();
    final glyph = (pass ~/ 4) % 3;
    final col = 1 + pass % 4;
    var on = 0;
    for (var r = row - 1; r <= row + 1; r++) {
      if (r < 0 || r > 5) continue;
      for (var c = col - 1; c <= col + 1; c++) {
        if (_bit(glyph, r, c)) on++;
      }
    }
    return on / 9;
  }

  static bool _bit(int glyph, int row, int col) =>
      (_glyphs[glyph * 6 + row] >> (5 - col)) & 1 == 1;

  /// The input thumbnail and its scanning window.
  static void _image(FrameContext ctx, double phase, double density) {
    final layout = ctx.layout;
    final left = _thumbLeft(layout);
    if (left.isNaN) return;
    final top = _thumbTop(layout);
    final px = _pixel(layout);
    final ma = ctx.motifAlpha;
    final frame = ctx.frame;
    final colors = ctx.colors;
    final dst = layout.layerSize(1);
    final src = layout.layerSize(0);

    final step = phase.floor();
    final frac = phase - step;
    final pass = (step / dst).floor();
    final glyph = (pass ~/ 4) % 3;
    final previousPass = ((step - 1) / dst).floor();
    final previousGlyph = (previousPass ~/ 4) % 3;
    final glide = easeInOutCubic(clamp01(frac / 0.4));
    // A new image fades in as the window returns to the top.
    final swap = glyph == previousGlyph ? 1.0 : glide;

    // The 3×3 window: its row follows the bracket, its column advances
    // with each pass. Pixels light by how much of them it covers.
    final j = step % dst, before = (step - 1) % dst;
    final row = lerp(
      _center(before, src, dst).toDouble(),
      _center(j, src, dst).toDouble(),
      glide,
    );
    final col = lerp(
      (1 + previousPass % 4).toDouble(),
      (1 + pass % 4).toDouble(),
      glide,
    );
    final cell = px - 0.8;
    for (var r = 0; r < 6; r++) {
      final cy = top + (r + 0.5) * px;
      final coverY = clamp01(2 - (r - row).abs());
      for (var c = 0; c < 6; c++) {
        final cx = left + (c + 0.5) * px;
        final now = _bit(glyph, r, c) ? 1.0 : 0.0;
        final was = _bit(previousGlyph, r, c) ? 1.0 : 0.0;
        final ink = lerp(was, now, swap);
        final cover = coverY * clamp01(2 - (c - col).abs());
        if (ink > 0.01) {
          frame.glow.add(
            Sprites.cell,
            cx,
            cy,
            cell * 12 / 10,
            colors.textSecondary,
            0.4 * ink * (1 - cover) * ma,
          );
        }
        if (cover > 0.01) {
          frame.glow.add(
            Sprites.cell,
            cx,
            cy,
            cell * 12 / 10,
            colors.signal,
            (0.1 + 0.75 * ink) * cover * ma,
          );
        }
      }
    }
    final wx = left + (col + 0.5) * px, wy = top + (row + 0.5) * px;
    final h = 1.5 * px + 1.5;
    final outline = 0.32 * ma;
    if (outline >= 0.08) {
      frame.litBucket(LineHue.signal, outline)
        ..add(wx - h, wy - h, wx + h, wy - h)
        ..add(wx + h, wy - h, wx + h, wy + h)
        ..add(wx + h, wy + h, wx - h, wy + h)
        ..add(wx - h, wy + h, wx - h, wy - h);
    }

    // A faint projection from the window to the bracket on the inputs.
    final first = layout.layerStart[0];
    final r = ctx.r[first];
    final bx = ctx.x[first] - r - 4.5;
    final by0 = _yAt(ctx, 0, row - 1) - r - 3;
    final by1 = _yAt(ctx, 0, row + 1) + r + 3;
    final beam = (0.1 + 0.12 * density) * ma;
    if (beam >= 0.08) {
      frame.litBucket(LineHue.signal, beam)
        ..add(wx + h + 2, wy - h, bx - 3, by0)
        ..add(wx + h + 2, wy + h, bx - 3, by1);
    }
  }
}
