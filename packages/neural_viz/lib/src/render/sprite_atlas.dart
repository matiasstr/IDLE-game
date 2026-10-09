import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A sprite's rectangle in the atlas, in logical pixels.
class SpriteCell {
  const SpriteCell(this.x, this.y, this.width, this.height);

  final double x, y, width, height;
}

/// The white sprites every glow is drawn with. Tinted per instance through
/// `drawRawAtlas` colors and blended additively, so soft light costs one
/// draw call and no blur at runtime.
abstract final class Sprites {
  /// Gaussian halo.
  static const glow = SpriteCell(1, 1, 64, 64);

  /// 1.5 px ring (ripples, prediction ring).
  static const ring = SpriteCell(67, 1, 48, 48);

  /// Dashed ring (progress ghosts).
  static const dashRing = SpriteCell(117, 1, 48, 48);

  /// Small soft dot (signal heads, cores).
  static const dot = SpriteCell(167, 1, 16, 16);

  /// Rounded square (CNN cells, kernel window).
  static const cell = SpriteCell(185, 1, 12, 12);

  /// Rounded pill (LLM tokens).
  static const pill = SpriteCell(199, 1, 20, 8);

  /// Comet trails, bright at the head (+x), fading to the tail.
  static const streak12 = SpriteCell(1, 67, 12, 8);
  static const streak24 = SpriteCell(15, 67, 24, 8);
  static const streak48 = SpriteCell(41, 67, 48, 8);
  static const streak96 = SpriteCell(91, 67, 96, 8);

  static const width = 256.0, height = 80.0;

  /// The streak whose length is closest to [length] (scaled 0.7–1.4×).
  static SpriteCell streakFor(double length) {
    if (length < 17) return streak12;
    if (length < 34) return streak24;
    if (length < 68) return streak48;
    return streak96;
  }
}

/// The atlas image at one pixel scale, shared by every view and released
/// when the last one is disposed.
class SpriteAtlas {
  SpriteAtlas._(this.scale, this.image);

  /// Pixels per logical pixel: `min(devicePixelRatio, 2)`.
  final double scale;
  final ui.Image image;
  int _refs = 0;

  static final Map<double, SpriteAtlas> _cache = {};

  /// Debug counter: atlases built so far.
  static int debugBuilds = 0;

  static SpriteAtlas acquire(double devicePixelRatio) {
    final scale = math.min(math.max(devicePixelRatio, 1.0), 2.0);
    final atlas = _cache[scale] ??= SpriteAtlas._(scale, _build(scale));
    atlas._refs++;
    return atlas;
  }

  void release() {
    if (--_refs > 0) return;
    _cache.remove(scale);
    image.dispose();
  }

  static ui.Image _build(double scale) {
    debugBuilds++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    const white = Color(0xFFFFFFFF);
    Color w(double a) => white.withValues(alpha: a);

    void radial(SpriteCell cell, List<double> stops, List<double> alphas) {
      final center = Offset(cell.x + cell.width / 2, cell.y + cell.height / 2);
      canvas.drawCircle(
        center,
        cell.width / 2,
        Paint()
          ..shader = ui.Gradient.radial(center, cell.width / 2, [
            for (final a in alphas) w(a),
          ], stops),
      );
    }

    radial(
      Sprites.glow,
      const [0, 0.2, 0.45, 0.7, 1],
      const [1, 0.55, 0.2, 0.05, 0],
    );
    radial(Sprites.dot, const [0, 0.35, 0.7, 1], const [1, 0.85, 0.25, 0]);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = white
      ..isAntiAlias = true;
    final ringCenter = Offset(
      Sprites.ring.x + Sprites.ring.width / 2,
      Sprites.ring.y + Sprites.ring.height / 2,
    );
    canvas.drawCircle(ringCenter, 21, stroke);

    final dashCenter = Offset(
      Sprites.dashRing.x + Sprites.dashRing.width / 2,
      Sprites.dashRing.y + Sprites.dashRing.height / 2,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = white;
    const dashes = 12;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: dashCenter, radius: 21),
        2 * math.pi * i / dashes,
        math.pi / dashes,
        false,
        dash,
      );
    }

    final cell = Sprites.cell;
    canvas.drawRRect(
      RRect.fromLTRBR(
        cell.x + 1,
        cell.y + 1,
        cell.x + cell.width - 1,
        cell.y + cell.height - 1,
        const Radius.circular(2.5),
      ),
      Paint()..color = white,
    );

    final pill = Sprites.pill;
    canvas.drawRRect(
      RRect.fromLTRBR(
        pill.x + 1,
        pill.y + 1,
        pill.x + pill.width - 1,
        pill.y + pill.height - 1,
        const Radius.circular(3),
      ),
      Paint()..color = w(0.9),
    );

    for (final s in const [
      Sprites.streak12,
      Sprites.streak24,
      Sprites.streak48,
      Sprites.streak96,
    ]) {
      final rect = Rect.fromLTWH(s.x + 1, s.y + 2.5, s.width - 2, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
          ..shader = ui.Gradient.linear(
            rect.centerLeft,
            rect.centerRight,
            [w(0), w(0.35), w(1)],
            const [0, 0.6, 1],
          ),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (Sprites.width * scale).ceil(),
      (Sprites.height * scale).ceil(),
    );
    picture.dispose();
    return image;
  }
}
