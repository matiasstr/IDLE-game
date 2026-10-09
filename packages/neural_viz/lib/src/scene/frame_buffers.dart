import 'dart:math' as math;
import 'dart:typed_data';

import '../render/sprite_atlas.dart';
import 'edge_style.dart';

/// Sprite instances for one `drawRawAtlas` call, preallocated.
class SpriteBatch {
  SpriteBatch(this.capacity)
    : transforms = Float32List(capacity * 4),
      rects = Float32List(capacity * 4),
      colors = Int32List(capacity);

  final int capacity;
  final Float32List transforms, rects;
  final Int32List colors;
  int count = 0;

  /// Scale of the atlas the rects refer to (pixels per logical pixel).
  double atlasScale = 1;

  void clear() => count = 0;

  /// Adds [cell] centered at (cx, cy), [width] logical pixels wide (the
  /// height follows the cell's aspect), rotated by [rotation] radians, tinted
  /// with [rgb] at [alpha] (0–1). Nearly invisible instances are skipped.
  void add(
    SpriteCell cell,
    double cx,
    double cy,
    double width,
    int rgb,
    double alpha, [
    double rotation = 0,
  ]) {
    if (count >= capacity || alpha < 1 / 255 || width <= 0.05) return;
    final a = (alpha >= 1 ? 255 : (alpha * 255).round()) & 0xff;
    final i = count * 4;
    final px = cell.width * atlasScale, py = cell.height * atlasScale;
    final scale = width / px;
    final scos = rotation == 0 ? scale : scale * math.cos(rotation);
    final ssin = rotation == 0 ? 0.0 : scale * math.sin(rotation);
    final ax = px / 2, ay = py / 2;
    transforms[i] = scos;
    transforms[i + 1] = ssin;
    transforms[i + 2] = cx - scos * ax + ssin * ay;
    transforms[i + 3] = cy - ssin * ax - scos * ay;
    rects[i] = cell.x * atlasScale;
    rects[i + 1] = cell.y * atlasScale;
    rects[i + 2] = (cell.x + cell.width) * atlasScale;
    rects[i + 3] = (cell.y + cell.height) * atlasScale;
    colors[count] = (a << 24) | (rgb & 0xffffff);
    count++;
  }

  Float32List get transformView =>
      Float32List.sublistView(transforms, 0, count * 4);
  Float32List get rectView => Float32List.sublistView(rects, 0, count * 4);
  Int32List get colorView => Int32List.sublistView(colors, 0, count);
}

/// Line segments for one `drawRawPoints(PointMode.lines)` call.
class LineBucket {
  LineBucket(this.capacity) : points = Float32List(capacity * 4);

  final int capacity;
  final Float32List points;
  int count = 0;

  void clear() => count = 0;

  void add(double x1, double y1, double x2, double y2) {
    if (count >= capacity) return;
    final i = count * 4;
    points[i] = x1;
    points[i + 1] = y1;
    points[i + 2] = x2;
    points[i + 3] = y2;
    count++;
  }

  Float32List get view => Float32List.sublistView(points, 0, count * 4);
}

/// Hues a line bucket can have.
enum LineHue { signal, structure, positive, negative, success, accent }

/// Everything the dynamic layer draws in one frame. Allocated once per scene
/// and refilled every frame, so the hot path allocates nothing.
class FrameBuffers {
  FrameBuffers();

  static const maxNeurons = 160;
  static const alphaLevels = [0.15, 0.32, 0.55, 0.85];

  /// Additive sprites below the neuron cores: halos, trails, signal heads,
  /// ghosts, ripples, tokens.
  final glow = SpriteBatch(900);

  /// Additive sprites drawn last: hot cores and prediction rings.
  final cores = SpriteBatch(320);

  /// Additive lit lines, by hue and alpha level.
  final lit = [
    for (var h = 0; h < LineHue.values.length; h++)
      [for (final _ in alphaLevels) LineBucket(1200)],
  ];

  /// Plain (srcOver) edges drawn while the static picture can't be used:
  /// during transitions and for the rotating AGI rings. Indexed
  /// `[negative ? 1 : 0][EdgeStyle level][wide ? 1 : 0]`.
  final base = [
    for (var sign = 0; sign < 2; sign++)
      [
        for (final _ in EdgeStyle.levels) [LineBucket(400), LineBucket(200)],
      ],
  ];

  /// Neuron bodies drawn dynamically (same conditions as [base]).
  final bodyX = Float32List(maxNeurons), bodyY = Float32List(maxNeurons);
  final bodyR = Float32List(maxNeurons), bodyAlpha = Float32List(maxNeurons);
  final bodyShape = Uint8List(maxNeurons);
  int bodyCount = 0;

  /// Expanding shockwave rings: center, radius, alpha, rgb.
  final ringX = Float32List(4), ringY = Float32List(4);
  final ringRadius = Float32List(4), ringAlpha = Float32List(4);
  final ringRgb = Int32List(4);
  int ringCount = 0;

  /// Opacity of the static network picture drawn by the dynamic layer while
  /// a transition settles (0 = not drawn).
  double networkPictureAlpha = 0;

  /// Opacity of the outgoing network picture during a crossfade.
  double previousPictureAlpha = 0;

  /// Uniform scale around [scaleCenterX], [scaleCenterY] (the push-in).
  double scale = 1, scaleCenterX = 0, scaleCenterY = 0;

  void clear() {
    glow.clear();
    cores.clear();
    for (final buckets in lit) {
      for (final b in buckets) {
        b.clear();
      }
    }
    for (final levels in base) {
      for (final widths in levels) {
        widths[0].clear();
        widths[1].clear();
      }
    }
    bodyCount = 0;
    ringCount = 0;
    networkPictureAlpha = 0;
    previousPictureAlpha = 0;
    scale = 1;
    scaleCenterX = 0;
    scaleCenterY = 0;
  }

  /// Picks the alpha level closest to [alpha] (0–1).
  static int level(double alpha) {
    if (alpha < 0.235) return 0;
    if (alpha < 0.435) return 1;
    if (alpha < 0.70) return 2;
    return 3;
  }

  LineBucket litBucket(LineHue hue, double alpha) =>
      lit[hue.index][level(alpha)];

  /// Adds an edge in its static style (see [EdgeStyle]).
  void addBaseEdge(
    double x1,
    double y1,
    double x2,
    double y2,
    bool negative,
    double alpha,
    bool wide,
  ) {
    if (alpha < 0.02) return;
    base[negative ? 1 : 0][EdgeStyle.level(alpha)][wide ? 1 : 0].add(
      x1,
      y1,
      x2,
      y2,
    );
  }

  void addBody(double x, double y, double r, double alpha, int shape) {
    if (bodyCount >= maxNeurons || alpha <= 0.004 || r <= 0.05) return;
    bodyX[bodyCount] = x;
    bodyY[bodyCount] = y;
    bodyR[bodyCount] = r;
    bodyAlpha[bodyCount] = alpha > 1 ? 1 : alpha;
    bodyShape[bodyCount] = shape;
    bodyCount++;
  }

  void addRing(double x, double y, double radius, double alpha, int rgb) {
    if (ringCount >= ringX.length || alpha <= 0.004) return;
    ringX[ringCount] = x;
    ringY[ringCount] = y;
    ringRadius[ringCount] = radius;
    ringAlpha[ringCount] = alpha;
    ringRgb[ringCount] = rgb;
    ringCount++;
  }
}
