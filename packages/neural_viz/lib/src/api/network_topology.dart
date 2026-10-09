import 'package:flutter/foundation.dart';

import 'network_kind.dart';

/// What to draw: an architecture kind and its neurons per layer.
///
/// Has value equality, so rebuilding a view with an equal topology is free.
@immutable
class NetworkTopology {
  const NetworkTopology({
    required this.kind,
    required this.layers,
    this.seed = 0,
  });

  /// Builds a topology from an engine architecture:
  /// `NetworkTopology.fromId(arch.id, arch.layers)`.
  NetworkTopology.fromId(String id, List<int> layers, {int seed = 0})
    : this(kind: NetworkKind.fromId(id), layers: layers, seed: seed);

  /// Supported number of layers.
  static const minLayers = 2, maxLayers = 8;

  /// Supported neurons per layer.
  static const minNeurons = 1, maxNeurons = 16;

  final NetworkKind kind;

  /// Neurons per layer, input first. Supported: 2–8 layers of 1–16 neurons
  /// (asserted in debug, clamped in release).
  final List<int> layers;

  /// Varies weights, highways and signal routes. The same seed, input
  /// history and time always give the same pixels.
  final int seed;

  int get neuronCount {
    var total = 0;
    for (final n in layers) {
      total += n;
    }
    return total;
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkTopology &&
      other.kind == kind &&
      other.seed == seed &&
      listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hash(kind, seed, Object.hashAll(layers));

  @override
  String toString() => 'NetworkTopology(${kind.name}, $layers, seed: $seed)';
}
