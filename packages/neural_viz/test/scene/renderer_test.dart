import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/render/scene_renderer.dart';
import 'package:neural_viz/src/scene/frame_buffers.dart';
import 'package:neural_viz/src/scene/layout.dart';

import '../helpers/viz_fixtures.dart';

/// Paints the scene's current frame into a recording canvas, like the
/// dynamic painter does.
RecordingCanvas _paint(SceneDriver d, double t) {
  d.frameAt(t);
  final canvas = RecordingCanvas();
  SceneRenderer(const NeuralVizTheme()).paint(
    canvas,
    d.frame,
    d.scene.atlas!,
    network: d.scene.network,
    previousNetwork: d.scene.previousNetwork,
  );
  return canvas;
}

int _bodies(FrameBuffers f, NeuronShape shape) {
  var n = 0;
  for (var i = 0; i < f.bodyCount; i++) {
    if (f.bodyShape[i] == shape.index) n++;
  }
  return n;
}

/// Sprite batches, lit-line buckets and plain edge buckets.
const _maxBatchedCalls = 2 + 6 * 4 + 2 * 6 * 2;

void main() {
  group('dynamic layer', () {
    test('at rest it only issues batched calls, never a layer', () {
      for (var stage = 0; stage < 8; stage++) {
        final d = SceneDriver(stage, production: 1e9, progress: 0.97)
          ..tap([2.0, 2.4]);
        for (var t = 1.0; t < 4; t += 0.1) {
          final canvas = _paint(d, t);
          final f = d.frame;
          final reason = 'stage $stage at $t';
          for (final method in const [
            'saveLayer',
            'drawPicture',
            'drawParagraph',
            'drawVertices',
            'drawImage',
            'drawImageRect',
          ]) {
            expect(canvas.count(method), 0, reason: '$method $reason');
          }
          // Per-instance calls only for rings and dynamic bodies (the
          // rotating AGI rings), two per body.
          expect(
            canvas.count('drawCircle'),
            f.ringCount + 2 * _bodies(f, NeuronShape.circle),
            reason: reason,
          );
          expect(canvas.count('drawRRect'), 2 * _bodies(f, NeuronShape.square));
          expect(canvas.count('drawPath'), 2 * _bodies(f, NeuronShape.diamond));
          if (stage != NetworkKind.agi.index) expect(f.bodyCount, 0);
          expect(
            canvas.count('drawRawAtlas') + canvas.count('drawRawPoints'),
            lessThanOrEqualTo(_maxBatchedCalls),
          );
          expect(canvas.count('drawRawAtlas'), lessThanOrEqualTo(2));
        }
        d.dispose();
      }
    });

    test('while transforming, layers only fade whole pictures', () {
      for (final (from, to) in const [(1, 2), (5, 6), (6, 7), (7, 0), (3, 3)]) {
        final d = SceneDriver(from, production: 1e6)..frameAt(0.5);
        d.goTo(
          1,
          to,
          newTopology: from == to ? stageTopology(to, seed: 4) : null,
        );
        for (var t = 1.0; t < 3.5; t += 0.05) {
          final canvas = _paint(d, t);
          final f = d.frame;
          var fades = 0;
          if (f.previousPictureAlpha > 0 && f.previousPictureAlpha < 1) {
            fades++;
          }
          if (f.networkPictureAlpha > 0 && f.networkPictureAlpha < 1) {
            fades++;
          }
          expect(canvas.count('saveLayer'), fades, reason: '$from → $to $t');
          expect(canvas.count('drawParagraph'), 0);
          expect(canvas.count('drawVertices'), 0);
        }
        d.dispose();
      }
    });
  });
}
