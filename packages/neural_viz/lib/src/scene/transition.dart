import 'dart:typed_data';

import '../api/viz_types.dart';
import 'hash.dart';
import 'layout.dart';

/// A topology change in progress: timings plus the neuron mapping that makes
/// "mitosis" literal (every new neuron grows out of an old one).
class SceneTransition {
  SceneTransition({
    required this.info,
    required this.start,
    required this.to,
    required this.reducedMotion,
    this.from,
    Float32List? fromX,
    Float32List? fromY,
    Float32List? fromR,
    Float32List? fromA,
    this.fromContrast = 0,
    this.initialHandover = 0,
  }) : fromX = fromX ?? Float32List(0),
       fromY = fromY ?? Float32List(0),
       fromR = fromR ?? Float32List(0),
       fromA = fromA ?? Float32List(0),
       parent = Int32List(to.neuronCount),
       firstChild = Uint8List(to.neuronCount),
       orphan = Uint8List(from?.neuronCount ?? 0) {
    final from = this.from;
    if (from != null && style == TransitionStyle.mitosis) {
      _mapParents(from, to, parent, firstChild, orphan);
    } else {
      parent.fillRange(0, parent.length, -1);
    }
  }

  final VizTransition info;
  final double start;
  final NetworkLayout to;

  /// The layout being replaced (null for the intro).
  final NetworkLayout? from;

  /// Where the old neurons were drawn when the transition started, so an
  /// interrupted transition never jumps.
  final Float32List fromX, fromY, fromR;

  /// How opaque each old neuron was (back-of-ring units are dimmer).
  final Float32List fromA;

  /// The training contrast the old network was drawn with, so its weights
  /// keep their look instead of snapping to the new stage's contrast.
  final double fromContrast;

  /// How far the outgoing picture had already handed over to the dynamic
  /// drawing when this transition started (1: no picture on screen).
  final double initialHandover;

  /// Picture-to-dynamic handover progress at [el] seconds in, 0–1.
  double handoverAt(double el) =>
      (initialHandover + el / pictureHandover).clamp(0.0, 1.0);

  /// For each new neuron, the old neuron it grows out of (-1: none).
  final Int32List parent;

  /// 1 when a new neuron is its parent's first child: it moves instead of
  /// growing from nothing.
  final Uint8List firstChild;

  /// 1 for old neurons without children: they shrink away.
  final Uint8List orphan;

  final bool reducedMotion;

  bool peakFired = false, endFired = false;

  TransitionStyle get style {
    if (reducedMotion || info.kind == VizTransitionKind.crossfade) {
      return TransitionStyle.crossfade;
    }
    return switch (info.kind) {
      VizTransitionKind.evolve => TransitionStyle.mitosis,
      VizTransitionKind.reset => TransitionStyle.collapse,
      VizTransitionKind.intro => TransitionStyle.unfold,
      VizTransitionKind.crossfade => TransitionStyle.crossfade,
    };
  }

  double get duration => switch (style) {
    TransitionStyle.mitosis => 2.4,
    TransitionStyle.collapse => 1.6,
    TransitionStyle.unfold => 0.9,
    TransitionStyle.crossfade => reducedMotion ? 0.3 : 0.4,
  };

  /// When the climax happens, relative to [start].
  double get peakAt => switch (style) {
    TransitionStyle.mitosis => 0.4,
    TransitionStyle.collapse => 0.7,
    TransitionStyle.unfold => 0,
    TransitionStyle.crossfade => duration / 2,
  };

  /// When the static picture starts fading in over the dynamic drawing,
  /// relative to [start]. Flights and weaves finish before it (for the
  /// stages they target), so the two never show a double image.
  double get settleAt => switch (style) {
    TransitionStyle.mitosis => 1.95,
    TransitionStyle.collapse => 1.32,
    TransitionStyle.unfold => 0.45,
    TransitionStyle.crossfade => 0,
  };

  /// When the new network's neurons start appearing, relative to [start].
  /// Before that the old network is all that's on screen.
  double get spawnAt => switch (style) {
    TransitionStyle.mitosis => 0.45,
    TransitionStyle.collapse => 0.75,
    TransitionStyle.unfold || TransitionStyle.crossfade => 0,
  };

  /// How long the outgoing static picture (captions, motif decorations)
  /// takes to hand over to the dynamically drawn old network.
  static const pictureHandover = 0.2;

  /// How long a new neuron takes to fly to its place.
  double get flight => style == TransitionStyle.collapse ? 0.5 : 0.65;

  /// Whether the app is told about this transition (the intro is silent).
  bool get notifies => info.kind != VizTransitionKind.intro;

  double elapsed(double t) => t - start;
  bool isDone(double t) => t - start >= duration;

  /// When new edge [e] starts drawing, relative to [start].
  double weaveStart(int e, int layer) => switch (style) {
    TransitionStyle.mitosis =>
      0.85 + 0.07 * layer + 0.12 * hash01(to.topology.seed, 5000 + e),
    TransitionStyle.collapse =>
      0.95 + 0.06 * layer + 0.10 * hash01(to.topology.seed, 5000 + e),
    TransitionStyle.unfold =>
      0.08 * layer + 0.10 * hash01(to.topology.seed, 5000 + e),
    TransitionStyle.crossfade => 0,
  };

  static const weaveDuration = 0.25;

  /// Parent of new neuron (l', i'): old layer round(l'·(L−1)/(L'−1)), old
  /// index round((i' + ½)·n/n' − ½). The first child of each parent keeps
  /// its identity and moves; the others split off.
  static void _mapParents(
    NetworkLayout from,
    NetworkLayout to,
    Int32List parent,
    Uint8List firstChild,
    Uint8List orphan,
  ) {
    final hasChild = Uint8List(from.neuronCount);
    final fromL = from.layerCount, toL = to.layerCount;
    for (var l = 0; l < toL; l++) {
      final oldLayer = toL == 1 ? 0 : (l * (fromL - 1) / (toL - 1)).round();
      final oldN = from.layerSize(oldLayer), newN = to.layerSize(l);
      for (var i = 0; i < newN; i++) {
        final oldIndex = ((i + 0.5) * oldN / newN - 0.5).round().clamp(
          0,
          oldN - 1,
        );
        final p = from.layerStart[oldLayer] + oldIndex;
        final n = to.layerStart[l] + i;
        parent[n] = p;
        if (hasChild[p] == 0) {
          hasChild[p] = 1;
          firstChild[n] = 1;
        }
      }
    }
    for (var p = 0; p < from.neuronCount; p++) {
      orphan[p] = hasChild[p] == 0 ? 1 : 0;
    }
  }
}

enum TransitionStyle {
  /// Stage up: gather, peak, neurons divide and fly, edges weave in.
  mitosis,

  /// Stage down: the network collapses to a point and unfolds again.
  collapse,

  /// First mount: neurons pop in layer by layer.
  unfold,

  /// Opacity only (same stage, or reduced motion).
  crossfade,
}
