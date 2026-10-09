import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../api/network_kind.dart';
import '../api/network_topology.dart';
import 'hash.dart';

/// How a neuron body is drawn.
enum NeuronShape { circle, square, diamond }

/// Below this width the view drops captions and decorations that need room.
const kCaptionMinWidth = 380.0;

/// Below this width dense stages keep only their strongest edges.
const kCompactWidth = 480.0;

/// AGI rings are ellipses squashed vertically by this factor.
const kRingSquash = 0.62;

/// Where every neuron and edge of a topology goes at a given size.
///
/// Pure geometry: built once per topology, size and pixel ratio, then read by
/// the static recorder and the per-frame evaluator. Columns for stages 1–7,
/// counter-rotating rings for AGI (positions here are at t = 0).
class NetworkLayout {
  NetworkLayout._({
    required this.topology,
    required this.size,
    required this.content,
    required this.layerStart,
    required this.layerX,
    required this.x,
    required this.y,
    required this.radius,
    required this.shape,
    required this.layerOf,
    required this.edgeSrc,
    required this.edgeDst,
    required this.weight,
    required this.highway,
    required this.outStart,
    required this.outEdges,
    required this.gap,
    required this.pitch,
    required this.r,
    required this.captions,
    required this.captionY,
    required this.groupOf,
    required this.ringRadius,
    required this.ringAngle,
    required this.coreRadius,
  });

  factory NetworkLayout.build(
    NetworkTopology topology,
    Size size, {
    double devicePixelRatio = 1,
    bool showCaptions = true,
  }) => _LayoutBuilder(topology, size, devicePixelRatio, showCaptions).build();

  final NetworkTopology topology;
  final Size size;

  /// Area the network occupies, after insets and motif margins.
  final Rect content;

  /// Index of the first neuron of each layer; the last entry is the count.
  final Int32List layerStart;

  /// Horizontal center of each layer (columns only).
  final Float32List layerX;

  /// Neuron centers.
  final Float32List x, y;

  /// Neuron body radius.
  final Float32List radius;

  /// [NeuronShape] index per neuron.
  final Uint8List shape;
  final Int32List layerOf;

  /// Edges, ordered by layer pair and then by source.
  final Int32List edgeSrc, edgeDst;

  /// Edge weights in [-1, 1].
  final Float32List weight;

  /// Edges on a strong positive path from an input to each output.
  final Uint8List highway;

  /// Outgoing edges per neuron: `outEdges[outStart[n] .. outStart[n + 1])`.
  final Int32List outStart, outEdges;

  /// Distance between layer columns and between neurons in a column.
  final double gap, pitch;

  /// Base neuron radius.
  final double r;

  /// One caption per layer ('' for none), drawn at [layerX] and [captionY].
  /// Empty when captions are hidden.
  final List<String> captions;
  final double captionY;

  /// Multimodal input group per neuron (0 text, 1 image, 2 audio; -1 none).
  final Int8List groupOf;

  /// AGI only: radius of each ring (horizontal semi-axis) and each neuron's
  /// angle at t = 0. Empty otherwise.
  final Float32List ringRadius, ringAngle;
  final double coreRadius;

  NetworkKind get kind => topology.kind;
  int get layerCount => layerStart.length - 1;
  int get neuronCount => layerStart[layerStart.length - 1];
  int get edgeCount => edgeSrc.length;
  bool get isRings => kind == NetworkKind.agi;
  Offset get center => content.center;

  int layerSize(int layer) => layerStart[layer + 1] - layerStart[layer];

  /// Angular speed of a ring in radians per second; rings alternate
  /// direction and outer rings turn faster.
  static double ringOmega(int ring) =>
      (ring.isEven ? 1 : -1) * 2 * math.pi / (140 - 20 * ring);
}

class _LayoutBuilder {
  _LayoutBuilder(this.topology, this.size, this.dpr, this.showCaptions)
    : layers = _clampLayers(topology.layers);

  final NetworkTopology topology;
  final Size size;
  final double dpr;
  final bool showCaptions;
  final List<int> layers;

  NetworkKind get kind => topology.kind;
  int get seed => topology.seed;

  static List<int> _clampLayers(List<int> layers) {
    assert(
      layers.length >= NetworkTopology.minLayers &&
          layers.length <= NetworkTopology.maxLayers &&
          layers.every(
            (n) =>
                n >= NetworkTopology.minNeurons &&
                n <= NetworkTopology.maxNeurons,
          ),
      'Unsupported layers $layers: use 2–8 layers of 1–16 neurons.',
    );
    final clamped = [
      for (final n in layers.take(NetworkTopology.maxLayers))
        n.clamp(NetworkTopology.minNeurons, NetworkTopology.maxNeurons),
    ];
    while (clamped.length < NetworkTopology.minLayers) {
      clamped.add(1);
    }
    return clamped;
  }

  double snap(double v) => (v * dpr).roundToDouble() / dpr;

  NetworkLayout build() {
    final w = size.width, h = size.height;
    final captions = showCaptions && w >= kCaptionMinWidth
        ? _captionsFor(kind, layers.length)
        : const <String>[];
    final captionBand = captions.isEmpty ? 0.0 : 16.0;

    // Insets plus the room each motif reserves around the network.
    var left = math.max(16.0, 0.08 * w), right = left;
    var top = math.max(14.0, 0.12 * h), bottom = top + captionBand;
    switch (kind) {
      case NetworkKind.rnn:
        left += 0.07 * w;
        top += 0.10 * h;
      case NetworkKind.llm:
        top += 0.12 * h;
        right += 44;
      case NetworkKind.transformer:
        bottom += 0.08 * h;
      case NetworkKind.multimodal:
        left += w >= kCompactWidth ? 68 : 28;
      case NetworkKind.cnn:
        if (w >= kCompactWidth) left += 48;
      case NetworkKind.perceptron || NetworkKind.mlp || NetworkKind.agi:
        break;
    }
    final content = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, w - right),
      math.max(top + 1, h - bottom),
    );

    final count = layers.fold(0, (a, b) => a + b);
    final layerStart = Int32List(layers.length + 1);
    for (var l = 0; l < layers.length; l++) {
      layerStart[l + 1] = layerStart[l] + layers[l];
    }
    final layerOf = Int32List(count);
    for (var l = 0; l < layers.length; l++) {
      for (var n = layerStart[l]; n < layerStart[l + 1]; n++) {
        layerOf[n] = l;
      }
    }
    final x = Float32List(count), y = Float32List(count);
    final radius = Float32List(count);
    final shape = Uint8List(count);
    final groupOf = Int8List(count)..fillRange(0, count, -1);
    final layerX = Float32List(layers.length);

    double gap, pitch, r;
    var ringRadius = Float32List(0), ringAngle = Float32List(0);
    var coreRadius = 0.0;
    var captionY = 0.0;

    if (kind == NetworkKind.agi) {
      final rMax = math.min(
        content.width / 2,
        content.height / (2 * kRingSquash),
      );
      ringRadius = Float32List(layers.length);
      ringAngle = Float32List(count);
      var spacing = double.infinity;
      for (var k = 0; k < layers.length; k++) {
        ringRadius[k] =
            rMax * (0.30 + 0.70 * k / math.max(1, layers.length - 1));
        spacing = math.min(spacing, 2 * math.pi * ringRadius[k] / layers[k]);
      }
      r = (0.30 * spacing).clamp(3.5, 9.0);
      coreRadius = 0.14 * rMax;
      gap = rMax * 0.175;
      pitch = spacing;
      final c = content.center;
      for (var k = 0; k < layers.length; k++) {
        final offset = hash01(seed, 900 + k) * 2 * math.pi;
        for (var i = 0; i < layers[k]; i++) {
          final n = layerStart[k] + i;
          final a = offset + 2 * math.pi * i / layers[k];
          ringAngle[n] = a;
          x[n] = c.dx + ringRadius[k] * math.cos(a);
          y[n] = c.dy + ringRadius[k] * kRingSquash * math.sin(a);
          radius[n] = r;
        }
      }
    } else {
      final columns = layers.length - 1;
      gap = math.min(
        content.width / columns,
        layers.length == 2 ? 240.0 : 170.0,
      );
      final maxN = layers.reduce(math.max);
      // Multimodal inputs leave room for the gaps between modality groups.
      final rows = kind == NetworkKind.multimodal
          ? math.max(maxN.toDouble(), layers[0] + 1.2)
          : maxN.toDouble();
      pitch = math.min(math.min(content.height / rows, 0.9 * gap), 44.0);
      final factor = switch (kind) {
        NetworkKind.perceptron => 1.25,
        NetworkKind.mlp => 1.1,
        _ => 1.0,
      };
      r = (0.30 * pitch).clamp(3.5, 11.0) * factor;
      final x0 = content.center.dx - gap * columns / 2;
      var lowest = 0.0;
      for (var l = 0; l < layers.length; l++) {
        layerX[l] = snap(x0 + gap * l);
        final ys = _columnYs(l, layers[l], pitch, content.center.dy);
        for (var i = 0; i < layers[l]; i++) {
          final n = layerStart[l] + i;
          x[n] = layerX[l];
          y[n] = snap(ys[i]);
          radius[n] = r;
          shape[n] = _shapeOf(l, i, layers[l]).index;
          if (kind == NetworkKind.multimodal && l == 0) {
            groupOf[n] = _groupOf(i, layers[0]);
          }
          lowest = math.max(lowest, y[n] + r);
        }
      }
      if (kind == NetworkKind.perceptron) {
        radius[count - 1] = r * 1.8;
        lowest = math.max(lowest, y[count - 1] + r * 1.8);
      }
      captionY = snap(math.min(lowest + 10, h - 8));
    }

    final edges = _edges(layerStart, w);
    final edgeCount = edges.src.length;
    final outStart = Int32List(count + 1);
    for (var e = 0; e < edgeCount; e++) {
      outStart[edges.src[e] + 1]++;
    }
    for (var n = 0; n < count; n++) {
      outStart[n + 1] += outStart[n];
    }
    final fill = Int32List.fromList(outStart);
    final outEdges = Int32List(edgeCount);
    for (var e = 0; e < edgeCount; e++) {
      outEdges[fill[edges.src[e]]++] = e;
    }

    return NetworkLayout._(
      topology: topology,
      size: size,
      content: content,
      layerStart: layerStart,
      layerX: layerX,
      x: x,
      y: y,
      radius: radius,
      shape: shape,
      layerOf: layerOf,
      edgeSrc: Int32List.fromList(edges.src),
      edgeDst: Int32List.fromList(edges.dst),
      weight: Float32List.fromList(edges.weight),
      highway: Uint8List.fromList(edges.highway),
      outStart: outStart,
      outEdges: outEdges,
      gap: gap,
      pitch: pitch,
      r: r,
      captions: captions,
      captionY: captionY,
      groupOf: groupOf,
      ringRadius: ringRadius,
      ringAngle: ringAngle,
      coreRadius: coreRadius,
    );
  }

  /// Vertical centers of a column, centered on [cy]. Multimodal inputs are
  /// split into text / image / audio groups with a gap between them.
  List<double> _columnYs(int layer, int n, double pitch, double cy) {
    if (kind != NetworkKind.multimodal || layer != 0 || n < 3) {
      return [for (var i = 0; i < n; i++) cy + (i - (n - 1) / 2) * pitch];
    }
    final ys = <double>[];
    var offset = 0.0;
    for (var i = 0; i < n; i++) {
      if (i > 0 && _groupOf(i, n) != _groupOf(i - 1, n)) offset += 0.6 * pitch;
      ys.add(i * pitch + offset);
    }
    final mid = (ys.first + ys.last) / 2;
    return [for (final v in ys) cy + v - mid];
  }

  /// Splits [n] inputs into three modality groups, e.g. 8 → 3/3/2.
  static int _groupOf(int i, int n) {
    final first = (n + 2) ~/ 3;
    final second = (n - first + 1) ~/ 2;
    return i < first ? 0 : (i < first + second ? 1 : 2);
  }

  NeuronShape _shapeOf(int layer, int i, int n) {
    switch (kind) {
      case NetworkKind.cnn:
        return layer < layers.length - 1
            ? NeuronShape.square
            : NeuronShape.circle;
      case NetworkKind.multimodal:
        if (layer != 0) return NeuronShape.circle;
        return switch (_groupOf(i, n)) {
          0 => NeuronShape.circle,
          1 => NeuronShape.square,
          _ => NeuronShape.diamond,
        };
      default:
        return NeuronShape.circle;
    }
  }

  _Edges _edges(Int32List layerStart, double width) {
    final edges = _Edges();
    if (kind == NetworkKind.agi) return edges; // AGI rewires every frame.
    final compact =
        width < kCompactWidth &&
        (kind == NetworkKind.transformer ||
            kind == NetworkKind.llm ||
            kind == NetworkKind.multimodal);
    for (var pair = 0; pair < layers.length - 1; pair++) {
      final srcN = layers[pair], dstN = layers[pair + 1];
      final s0 = layerStart[pair], d0 = layerStart[pair + 1];
      final firstOfPair = edges.src.length;
      for (var j = 0; j < dstN; j++) {
        final candidates = <int>[];
        for (var i = 0; i < srcN; i++) {
          if (_connected(pair, i, j, srcN, dstN)) candidates.add(i);
        }
        if (compact && candidates.length > 4) {
          candidates.sort(
            (a, b) => _w(pair, b, j).abs().compareTo(_w(pair, a, j).abs()),
          );
          candidates.removeRange(4, candidates.length);
        }
        for (final i in candidates) {
          edges.add(s0 + i, d0 + j, _w(pair, i, j));
        }
      }
      _sortBySource(edges, firstOfPair);
    }
    _markHighways(edges, layerStart);
    return edges;
  }

  double _w(int pair, int i, int j) => 2 * hash01(seed, 100 + pair, i, j) - 1;

  bool _connected(int pair, int i, int j, int srcN, int dstN) {
    if (kind == NetworkKind.cnn && pair < 2 && dstN > 1) {
      // Local receptive field: a window of 3 around the matching source.
      final center = (j * (srcN - 1) / (dstN - 1)).round();
      return (i - center).abs() <= 1;
    }
    if (kind == NetworkKind.multimodal && pair == 0 && srcN >= 3 && dstN >= 3) {
      // Encoders stay inside their modality lane until the fusion layer.
      return _groupOf(i, srcN) == _groupOf(j, dstN);
    }
    return true;
  }

  void _sortBySource(_Edges edges, int from) {
    final order = List.generate(edges.src.length - from, (k) => from + k)
      ..sort((a, b) {
        final bySrc = edges.src[a].compareTo(edges.src[b]);
        return bySrc != 0 ? bySrc : edges.dst[a].compareTo(edges.dst[b]);
      });
    final src = [for (final k in order) edges.src[k]];
    final dst = [for (final k in order) edges.dst[k]];
    final weight = [for (final k in order) edges.weight[k]];
    for (var k = 0; k < order.length; k++) {
      edges.src[from + k] = src[k];
      edges.dst[from + k] = dst[k];
      edges.weight[from + k] = weight[k];
    }
  }

  /// Gives each output neuron one strong positive path back to an input, so
  /// signals visibly favor "learned" routes.
  void _markHighways(_Edges edges, Int32List layerStart) {
    final incoming = <int, List<int>>{};
    for (var e = 0; e < edges.src.length; e++) {
      (incoming[edges.dst[e]] ??= []).add(e);
    }
    final last = layers.length - 1;
    for (var n = layerStart[last]; n < layerStart[last + 1]; n++) {
      var node = n;
      var hop = 0;
      while (incoming[node] != null) {
        final options = incoming[node]!;
        final e = options[hash32(seed, 700 + n, hop) % options.length];
        edges.highway[e] = 1;
        edges.weight[e] = 0.8 + 0.2 * hash01(seed, 800 + n, hop);
        node = edges.src[e];
        hop++;
      }
    }
  }

  static List<String> _captionsFor(NetworkKind kind, int layerCount) {
    final captions = switch (kind) {
      NetworkKind.perceptron => const ['x', 'ŷ'],
      NetworkKind.mlp => const ['in', 'hidden', 'out'],
      NetworkKind.cnn => const ['input', 'conv', 'pool', 'fc'],
      NetworkKind.rnn => const ['x(t)', 'h(t)', 'h(t)', 'y(t)'],
      NetworkKind.transformer => const ['embed', 'attn', 'attn', 'attn', 'out'],
      NetworkKind.llm => const ['tokens', '', 'blocks ×96', '', 'logits'],
      NetworkKind.multimodal => const ['', 'enc', 'fusion', 'dec', 'out'],
      NetworkKind.agi => const <String>[],
    };
    return captions.length == layerCount ? captions : const [];
  }
}

class _Edges {
  final src = <int>[];
  final dst = <int>[];
  final weight = <double>[];
  final highway = <int>[];

  void add(int s, int d, double w) {
    src.add(s);
    dst.add(d);
    weight.add(w);
    highway.add(0);
  }
}
