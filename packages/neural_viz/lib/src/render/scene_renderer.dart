import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../api/viz_theme.dart';
import '../scene/edge_style.dart';
import '../scene/frame_buffers.dart';
import 'body_painter.dart';
import 'sprite_atlas.dart';
import 'static_recorder.dart';

/// Draws a filled [FrameBuffers] with a fixed set of paints: at most a few
/// dozen draw calls per frame, no blur, no per-frame paths.
class SceneRenderer {
  SceneRenderer(NeuralVizTheme theme, {bool highContrast = false}) {
    update(theme, highContrast: highContrast);
  }

  late BodyPainter _bodies;
  late List<List<List<Paint>>> _base;
  late List<List<Paint>> _lit;
  final Paint _additive = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _layer = Paint();

  void update(NeuralVizTheme theme, {bool highContrast = false}) {
    _bodies = BodyPainter(theme, highContrast: highContrast);
    _base = [
      for (var negative = 0; negative < 2; negative++)
        [
          for (var level = 0; level < EdgeStyle.levels.length; level++)
            [
              StaticRecorder.edgePaint(theme, negative == 1, level, false),
              StaticRecorder.edgePaint(theme, negative == 1, level, true),
            ],
        ],
    ];
    final hues = <Color>[
      theme.signal,
      theme.structure,
      theme.structure,
      theme.textSecondary,
      theme.success,
      theme.accent,
    ];
    _lit = [
      for (final hue in hues)
        [
          for (final alpha in FrameBuffers.alphaLevels)
            Paint()
              ..color = hue.withValues(alpha: alpha)
              ..strokeWidth = 1.25
              ..strokeCap = StrokeCap.round
              ..blendMode = BlendMode.plus,
        ],
    ];
  }

  void paint(
    Canvas canvas,
    FrameBuffers f,
    SpriteAtlas atlas, {
    ui.Picture? network,
    ui.Picture? previousNetwork,
  }) {
    if (f.previousPictureAlpha > 0 && previousNetwork != null) {
      _faded(canvas, previousNetwork, f.previousPictureAlpha);
    }
    final scaled = f.scale != 1;
    if (scaled) {
      canvas
        ..save()
        ..translate(f.scaleCenterX, f.scaleCenterY)
        ..scale(f.scale)
        ..translate(-f.scaleCenterX, -f.scaleCenterY);
    }
    if (f.networkPictureAlpha > 0 && network != null) {
      _faded(canvas, network, f.networkPictureAlpha);
    }

    for (var negative = 0; negative < 2; negative++) {
      for (var level = 0; level < EdgeStyle.levels.length; level++) {
        for (var wide = 0; wide < 2; wide++) {
          final bucket = f.base[negative][level][wide];
          if (bucket.count == 0) continue;
          canvas.drawRawPoints(
            ui.PointMode.lines,
            bucket.view,
            _base[negative][level][wide],
          );
        }
      }
    }
    for (var i = 0; i < f.bodyCount; i++) {
      _bodies.paint(
        canvas,
        f.bodyX[i],
        f.bodyY[i],
        f.bodyR[i],
        f.bodyShape[i],
        f.bodyAlpha[i],
      );
    }
    for (var hue = 0; hue < f.lit.length; hue++) {
      for (var level = 0; level < f.lit[hue].length; level++) {
        final bucket = f.lit[hue][level];
        if (bucket.count == 0) continue;
        canvas.drawRawPoints(ui.PointMode.lines, bucket.view, _lit[hue][level]);
      }
    }
    _atlas(canvas, atlas, f.glow);
    _atlas(canvas, atlas, f.cores);
    for (var i = 0; i < f.ringCount; i++) {
      _ring.color = Color(
        ((f.ringAlpha[i] * 255).round() << 24) | (f.ringRgb[i] & 0xffffff),
      );
      canvas.drawCircle(Offset(f.ringX[i], f.ringY[i]), f.ringRadius[i], _ring);
    }
    if (scaled) canvas.restore();
  }

  void _atlas(Canvas canvas, SpriteAtlas atlas, SpriteBatch batch) {
    if (batch.count == 0) return;
    canvas.drawRawAtlas(
      atlas.image,
      batch.transformView,
      batch.rectView,
      batch.colorView,
      BlendMode.modulate,
      null,
      _additive,
    );
  }

  void _faded(Canvas canvas, ui.Picture picture, double alpha) {
    if (alpha >= 1) {
      canvas.drawPicture(picture);
      return;
    }
    _layer.color = Color.fromARGB((alpha * 255).round(), 0, 0, 0);
    canvas
      ..saveLayer(null, _layer)
      ..drawPicture(picture)
      ..restore();
  }
}
