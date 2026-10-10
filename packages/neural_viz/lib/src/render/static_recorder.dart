import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../api/viz_theme.dart';
import '../scene/edge_style.dart';
import '../scene/layout.dart';
import '../scene/motif.dart';
import 'body_painter.dart';

/// Records the parts of the view that only change with size, theme, stage
/// or training contrast into pictures, replayed every frame for free.
abstract final class StaticRecorder {
  /// Chamber gradient, dot grid, stage haze, vignette and crop marks.
  static ui.Picture background(
    Size size,
    NeuralVizTheme theme, {
    required int stage,
    required bool paintBackground,
    required bool cropMarks,
    required bool highContrast,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = size.width, h = size.height;
    final diagonal = math.sqrt(w * w + h * h);
    final center = Offset(0.5 * w, 0.47 * h);
    final bounds = Offset.zero & size;

    if (paintBackground) {
      canvas.drawRect(bounds, Paint()..color = theme.background);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.radial(center, 0.55 * diagonal, [
            theme.surface,
            theme.background,
          ]),
      );

      // Dot grid fading out from the center.
      final points = <double>[];
      const pitch = 22.0;
      for (var y = pitch / 2; y < h; y += pitch) {
        for (var x = pitch / 2; x < w; x += pitch) {
          points
            ..add(x)
            ..add(y);
        }
      }
      final gridAlpha = highContrast ? 0.075 : 0.05;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(points),
        Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.radial(center, 0.6 * diagonal, [
            theme.textPrimary.withValues(alpha: gridAlpha),
            theme.textPrimary.withValues(alpha: 0),
          ]),
      );

      // A faint haze tinted by stage: cyan early, violet later.
      final (haze, hazeAlpha) = switch (stage) {
        <= 2 => (theme.signal, 0.03),
        <= 5 => (theme.structure, 0.04),
        _ => (theme.structure, 0.05),
      };
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.radial(center, 0.45 * diagonal, [
            haze.withValues(alpha: hazeAlpha),
            haze.withValues(alpha: 0),
          ]),
      );
      if (stage >= 7) {
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = ui.Gradient.radial(center, 0.25 * diagonal, [
              theme.accent.withValues(alpha: 0.02),
              theme.accent.withValues(alpha: 0),
            ]),
        );
      }

      // Vignette.
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            0.75 * diagonal,
            [theme.background.withValues(alpha: 0), theme.background],
            const [0.55, 1],
          ),
      );
    }

    if (cropMarks) {
      final mark = Paint()
        ..color = theme.border
        ..strokeWidth = 1;
      const inset = 8.0, length = 8.0;
      for (final (x, dx) in [(inset, 1.0), (w - inset, -1.0)]) {
        for (final (y, dy) in [(inset, 1.0), (h - inset, -1.0)]) {
          canvas
            ..drawLine(Offset(x, y), Offset(x + dx * length, y), mark)
            ..drawLine(Offset(x, y), Offset(x, y + dy * length), mark);
        }
      }
    }
    return recorder.endRecording();
  }

  /// Motif underlay, edges, bodies, motif overlay and captions.
  static ui.Picture network(StaticContext ctx, Motif motif) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final layout = ctx.layout;
    final theme = ctx.theme;

    motif.paintUnder(canvas, ctx);

    if (layout.isRings) {
      // Rings rotate: only their guides are static.
      final guide = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.border;
      final c = layout.center;
      for (var k = 0; k < layout.layerCount; k++) {
        final rx = layout.ringRadius[k];
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: 2 * rx,
            height: 2 * rx * kRingSquash,
          ),
          guide,
        );
      }
    } else {
      paintEdges(canvas, layout, ctx.strength, theme, ctx.highContrast);
      final bodies = BodyPainter(theme, highContrast: ctx.highContrast);
      for (var i = 0; i < layout.neuronCount; i++) {
        bodies.paint(
          canvas,
          layout.x[i],
          layout.y[i],
          layout.radius[i],
          layout.shape[i],
        );
      }
    }

    motif.paintOver(canvas, ctx);
    _paintCaptions(canvas, layout, theme, ctx.highContrast);
    return recorder.endRecording();
  }

  /// Edges batched by sign, alpha level and width: one draw call each.
  static void paintEdges(
    Canvas canvas,
    NetworkLayout layout,
    Float32List strength,
    NeuralVizTheme theme,
    bool highContrast,
  ) {
    final levels = EdgeStyle.levels.length;
    final buckets = List.generate(2 * levels * 2, (_) => <double>[]);
    for (var e = 0; e < layout.edgeCount; e++) {
      final s = strength[e];
      final negative = layout.weight[e] < 0 ? 1 : 0;
      final level = EdgeStyle.level(
        EdgeStyle.alpha(s, highContrast: highContrast),
      );
      final wide = EdgeStyle.isWide(s) ? 1 : 0;
      final a = layout.edgeSrc[e], b = layout.edgeDst[e];
      buckets[(negative * levels + level) * 2 + wide].addAll([
        layout.x[a],
        layout.y[a],
        layout.x[b],
        layout.y[b],
      ]);
    }
    for (var negative = 0; negative < 2; negative++) {
      for (var level = 0; level < levels; level++) {
        for (var wide = 0; wide < 2; wide++) {
          final points = buckets[(negative * levels + level) * 2 + wide];
          if (points.isEmpty) continue;
          canvas.drawRawPoints(
            ui.PointMode.lines,
            Float32List.fromList(points),
            edgePaint(theme, negative == 1, level, wide == 1),
          );
        }
      }
    }
  }

  /// The paint for an edge style; the dynamic layer uses the same values.
  static Paint edgePaint(
    NeuralVizTheme theme,
    bool negative,
    int level,
    bool wide,
  ) {
    final color = negative ? theme.textSecondary : theme.structure;
    return Paint()
      ..color = color.withValues(alpha: EdgeStyle.levels[level])
      ..strokeWidth = wide ? EdgeStyle.wideWidth : EdgeStyle.width
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
  }

  static void _paintCaptions(
    Canvas canvas,
    NetworkLayout layout,
    NeuralVizTheme theme,
    bool highContrast,
  ) {
    if (layout.captions.isEmpty) return;
    final style = TextStyle(
      fontFamily: theme.monoFontFamily,
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: highContrast ? theme.textSecondary : theme.textMuted,
    );
    var lastRight = double.negativeInfinity;
    for (var l = 0; l < layout.layerCount; l++) {
      final text = layout.captions[l];
      if (text.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: isWordCaption(text) ? text.toUpperCase() : text,
          style: style,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final left = layout.layerX[l] - painter.width / 2;
      // Drop captions that would collide with the previous one.
      if (left > lastRight + 6) {
        painter.paint(canvas, Offset(left, layout.captionY));
        lastRight = left + painter.width;
      }
      painter.dispose();
    }
  }
}
