import 'dart:math' as math;

import 'package:neural_viz/neural_viz.dart';

/// One Neural Idle architecture. The values mirror `kArchitectures` in
/// neural_idle_core, copied so the example depends on neural_viz only.
class StageDef {
  const StageDef(this.id, this.name, this.layers, this.threshold, this.blurb);

  /// `ArchitectureDef.id`, also the [NetworkKind] name.
  final String id;
  final String name;
  final List<int> layers;

  /// Run tokens needed to reach this stage.
  final double threshold;

  /// One line for the gallery.
  final String blurb;

  NetworkKind get kind => NetworkKind.fromId(id);
  NetworkTopology get topology => NetworkTopology.fromId(id, layers);

  /// "6·8·6·3".
  String get shape => layers.join('·');
}

const stages = <StageDef>[
  StageDef('perceptron', 'Perceptron', [3, 1], 0, 'A weighted sum and a step.'),
  StageDef('mlp', 'MLP', [3, 5, 2], 300, 'Hidden layers, fully connected.'),
  StageDef(
    'cnn',
    'CNN',
    [6, 8, 6, 3],
    15000,
    'Local receptive fields slide over the input.',
  ),
  StageDef('rnn', 'RNN', [4, 7, 7, 4], 1e6, 'A hidden state carried in time.'),
  StageDef(
    'transformer',
    'Transformer',
    [6, 8, 8, 8, 6],
    5e7,
    'Attention heads weigh every position.',
  ),
  StageDef(
    'llm',
    'LLM',
    [8, 10, 10, 10, 8],
    2.5e9,
    'Causal attention, one token at a time.',
  ),
  StageDef(
    'multimodal',
    'Multimodal',
    [8, 10, 12, 10, 8],
    1.5e11,
    'Text, image and audio, fused.',
  ),
  StageDef(
    'agi',
    'AGI',
    [10, 12, 14, 12, 10],
    1e13,
    'Rings that rewire themselves.',
  ),
];

int get lastStage => stages.length - 1;

/// The next stage's topology, or null at the last stage.
NetworkTopology? nextTopologyOf(int stage) =>
    stage + 1 < stages.length ? stages[stage + 1].topology : null;

// ------------------------------------------------------- engine curve

double _log10(double x) => math.log(x) / math.ln10;

/// `GameEngine.accuracy`: 10% untrained, approaching 100% with every order of
/// magnitude of run tokens.
double engineAccuracy(double runTokens) =>
    1 - 0.9 * math.exp(-_log10(math.max(runTokens, 0) + 1) / 3);

/// `GameEngine.loss`: cross-entropy for [accuracy] (ln 10 ≈ 2.30 untrained).
double lossOf(double accuracy) => -math.log(accuracy.clamp(0.01, 1.0));

/// `GameEngine.stageIndex` for [runTokens].
int engineStage(double runTokens) {
  var index = 0;
  while (index < lastStage && runTokens >= stages[index + 1].threshold) {
    index++;
  }
  return index;
}

/// `GameEngine.stageProgress`: log-scale progress from [stage]'s threshold to
/// the next one; 1 at the last stage.
double engineProgress(double runTokens, int stage) {
  if (stage >= lastStage) return 1;
  final from = math.log(stages[stage].threshold + 1);
  final to = math.log(stages[stage + 1].threshold + 1);
  final now = math.log(math.max(runTokens, 0) + 1);
  return ((now - from) / (to - from)).clamp(0.0, 1.0);
}

/// Inverse of [engineProgress]: the run tokens at [progress] through [stage].
double tokensAt(int stage, double progress) {
  if (stage >= lastStage) return stages[lastStage].threshold;
  final from = math.log(stages[stage].threshold + 1);
  final to = math.log(stages[stage + 1].threshold + 1);
  return math.exp(from + (to - from) * progress.clamp(0.0, 1.0)) - 1;
}

/// The run tokens (orders of magnitude) at which [engineAccuracy] reaches
/// [accuracy].
double ordersForAccuracy(double accuracy) {
  if (accuracy <= 0.1) return 0;
  return -3 * math.log((1 - math.min(accuracy, 0.9999)) / 0.9);
}

/// A plausible run that ends at [stage] + [progress] with loss
/// `-ln(accuracy)`: one sample per second, loss following the engine curve
/// and a marker at every stage reached. Deterministic.
LossHistory syntheticLossHistory({
  required int stage,
  required double progress,
  required double accuracy,
  int samples = 200,
}) {
  final history = LossHistory();
  final endOrders = ordersForAccuracy(accuracy);
  final span = stage + progress.clamp(0.0, 1.0);
  var reached = 0;
  for (var i = 0; i < samples; i++) {
    final f = i / (samples - 1);
    if (span > 0) {
      final unit = math.min((f * span).floor(), stage);
      while (reached < unit) {
        reached++;
        history.mark(stages[reached].name);
      }
    }
    final orders = endOrders * f;
    final acc = 1 - 0.9 * math.exp(-orders / 3);
    history.add(lossOf(acc));
  }
  return history;
}

// --------------------------------------------------------- production

/// Production slider position (0–1) to tokens per second: 0 at the left end,
/// then log scale from 0.1/s to 1e12/s.
double productionAt(double position) {
  if (position <= 0.004) return 0;
  return math.pow(10, -1 + 13 * position.clamp(0.0, 1.0)).toDouble();
}

/// Inverse of [productionAt].
double positionOf(double production) {
  if (production <= 0) return 0;
  return ((_log10(production) + 1) / 13).clamp(0.0, 1.0);
}

/// Rounds [production] to two significant digits so slider values stay
/// readable and reproducible in capture URLs.
double roundProduction(double production) {
  if (production <= 0) return 0;
  final magnitude = math.pow(10, _log10(production).floor() - 1).toDouble();
  return (production / magnitude).roundToDouble() * magnitude;
}

/// Idle-game number format: "0", "0.5", "120", "4.2k", "1.2M", "3.4B",
/// "1.0T".
String formatCount(double value) {
  if (value.isNaN || value <= 0) return '0';
  if (value < 1) return value.toStringAsFixed(value < 0.1 ? 2 : 1);
  if (value < 1000) {
    return value < 10
        ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
        : value.round().toString();
  }
  const suffixes = ['k', 'M', 'B', 'T', 'Qa', 'Qi'];
  var scaled = value;
  var i = -1;
  while (scaled >= 1000 && i < suffixes.length - 1) {
    scaled /= 1000;
    i++;
  }
  final digits = scaled < 10 ? 2 : (scaled < 100 ? 1 : 0);
  return '${scaled.toStringAsFixed(digits)}${suffixes[i]}';
}

/// Compact number for URLs: "0", "2000", "1e+9" style is avoided in favour of
/// plain digits up to 1e6 and exponent form above ("1.5e9").
String formatParam(double value) {
  if (value == 0) return '0';
  if (value.abs() < 1e6 && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  if (value.abs() >= 1e6) {
    final exp = _log10(value.abs()).floor();
    final mantissa = value / math.pow(10, exp);
    final m = mantissa.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '${m}e$exp';
  }
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}
