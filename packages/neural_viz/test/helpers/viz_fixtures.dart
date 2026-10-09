import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/render/sprite_atlas.dart';
import 'package:neural_viz/src/scene/frame_buffers.dart';
import 'package:neural_viz/src/scene/viz_scene.dart';

/// Neurons per layer of each engine stage (`neural_idle_core`
/// architectures), indexed like [NetworkKind.values].
const stageLayers = <List<int>>[
  [3, 1],
  [3, 5, 2],
  [6, 8, 6, 3],
  [4, 7, 7, 4],
  [6, 8, 8, 8, 6],
  [8, 10, 10, 10, 8],
  [8, 10, 12, 10, 8],
  [10, 12, 14, 12, 10],
];

/// Run tokens at which the engine reaches each stage.
const stageThresholds = <double>[0, 300, 15000, 1e6, 5e7, 2.5e9, 1.5e11, 1e13];

/// Accuracy the engine reports when each stage is reached
/// (`GameEngine.accuracy`: 1 − 0.9·e^(−log10(tokens + 1)/3)).
final stageThresholdAccuracy = <double>[
  for (final tokens in stageThresholds)
    1 - 0.9 * math.exp(-(math.log(tokens + 1) / math.ln10) / 3),
];

/// Sizes the layout must handle, from small phones to desktop.
const layoutSizes = <Size>[
  Size(320, 200),
  Size(360, 240),
  Size(390, 280),
  Size(430, 320),
  Size(720, 440),
  Size(900, 520),
];

NetworkTopology stageTopology(int stage, {int seed = 0}) => NetworkTopology(
  kind: NetworkKind.values[stage],
  layers: stageLayers[stage],
  seed: seed,
);

/// The topology after [stage], or null at the last stage.
NetworkTopology? nextTopologyAfter(int stage, {int seed = 0}) =>
    stage + 1 < stageLayers.length
    ? stageTopology(stage + 1, seed: seed)
    : null;

/// A [VizScene] plus the inputs it was last given, so a test can change one
/// input at a time, like an app rebuilding the view.
class SceneDriver {
  /// A scene for [stage], inputs applied and laid out at [t]. The intro is
  /// off unless [playIntro] is set.
  SceneDriver(
    this.stage, {
    this.size = const Size(720, 440),
    this.dpr = 2,
    double t = 0,
    this.production = 1000,
    this.accuracy = 0.5,
    this.progress = 0.3,
    this.trainingCount = 0,
    bool lastStage = false,
    bool reducedMotion = false,
    bool playIntro = false,
    VizQuality quality = VizQuality.high,
    int seed = 0,
  }) : topology = stageTopology(stage, seed: seed),
       next = lastStage ? null : nextTopologyAfter(stage, seed: seed),
       scene =
           VizScene(
               topology: stageTopology(stage, seed: seed),
               stage: stage,
             )
             ..playIntro = playIntro
             ..reducedMotion = reducedMotion
             ..requestedQuality = quality {
    // Released even when the test fails half way, so shared resources (the
    // sprite atlas) don't leak into the next test.
    addTearDown(dispose);
    apply(t);
    scene.ensureLayout(size, dpr, t);
  }

  final VizScene scene;
  Size size;
  double dpr;
  NetworkTopology topology;
  int stage;
  NetworkTopology? next;
  double production, accuracy, progress;
  int trainingCount;

  FrameBuffers get frame => scene.frame;

  /// Feeds the current inputs, stamped with [t].
  void apply(double t) => scene.setInputs(
    t: t,
    topology: topology,
    stage: stage,
    nextTopology: next,
    productionPerSecond: production,
    trainingCount: trainingCount,
    progress: progress,
    accuracy: accuracy,
  );

  /// One training step at each of [times].
  void tap(List<double> times) {
    for (final t in times) {
      trainingCount++;
      apply(t);
    }
  }

  /// Moves to [newStage] (its engine topology unless [newTopology] is
  /// given) at [t].
  void goTo(double t, int newStage, {NetworkTopology? newTopology}) {
    stage = newStage;
    topology = newTopology ?? stageTopology(newStage);
    next = nextTopologyAfter(newStage);
    apply(t);
  }

  /// What a paint at [t] does: layout, then evaluate.
  FrameBuffers frameAt(double t) {
    scene.ensureLayout(size, dpr, t);
    scene.evaluate(t);
    return scene.frame;
  }

  bool _disposed = false;

  /// Disposes the scene (once; later calls do nothing).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scene.dispose();
  }
}

/// Everything the dynamic layer would draw, flattened, so two frames can be
/// compared exactly.
List<double> snapshot(FrameBuffers f) {
  final out = <double>[];
  void batch(SpriteBatch b) {
    out
      ..add(b.count.toDouble())
      ..add(b.atlasScale)
      ..addAll(b.transformView)
      ..addAll(b.rectView)
      ..addAll(b.colorView.map((c) => c.toDouble()));
  }

  void line(LineBucket b) {
    out
      ..add(b.count.toDouble())
      ..addAll(b.view);
  }

  batch(f.glow);
  batch(f.cores);
  for (final hue in f.lit) {
    hue.forEach(line);
  }
  for (final sign in f.base) {
    for (final level in sign) {
      level.forEach(line);
    }
  }
  out.add(f.bodyCount.toDouble());
  for (var i = 0; i < f.bodyCount; i++) {
    out.addAll([
      f.bodyX[i],
      f.bodyY[i],
      f.bodyR[i],
      f.bodyAlpha[i],
      f.bodyShape[i].toDouble(),
    ]);
  }
  out.add(f.ringCount.toDouble());
  for (var i = 0; i < f.ringCount; i++) {
    out.addAll([
      f.ringX[i],
      f.ringY[i],
      f.ringRadius[i],
      f.ringAlpha[i],
      f.ringRgb[i].toDouble(),
    ]);
  }
  out.addAll([
    f.networkPictureAlpha,
    f.previousPictureAlpha,
    f.scale,
    f.scaleCenterX,
    f.scaleCenterY,
  ]);
  return out;
}

/// Number of instances of the sprite [cell] in [batch] (matched by atlas
/// rectangle), optionally only those tinted [rgb].
int countSprites(SpriteBatch batch, SpriteCell cell, {int? rgb}) {
  var n = 0;
  for (var i = 0; i < batch.count; i++) {
    if (batch.rects[i * 4] == cell.x * batch.atlasScale &&
        batch.rects[i * 4 + 1] == cell.y * batch.atlasScale &&
        (rgb == null || batch.colors[i] & 0xffffff == rgb)) {
      n++;
    }
  }
  return n;
}

/// A [Canvas] that only records which methods were called.
class RecordingCanvas implements Canvas {
  final List<String> calls = [];

  int count(String method) => calls.where((c) => c == method).length;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    // Symbol("drawRawPoints") → drawRawPoints
    calls.add(name.substring(8, name.length - 2));
    return null;
  }
}
