// Prints when a greedy player reaches each architecture stage.
//
//   dart run tool/simulate.dart [hours] [tapsPerSecond]

import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_idle_core/simulation.dart';

void main(List<String> args) {
  final hours = args.isNotEmpty ? double.parse(args[0]) : 12;
  final taps = args.length > 1 ? int.parse(args[1]) : 4;
  const engine = GameEngine();
  final result = GreedyPlayer(tapsPerSecond: taps).play(
    Duration(seconds: (hours * 3600).round()),
    step: hours > 2 ? 5 : 1,
  );

  print('Greedy player, $taps taps/s, ${hours}h\n');
  print('${'stage'.padRight(14)}reached at');
  for (final (index, stage) in engine.content.architectures.indexed) {
    final seconds = result.stageReachedAt[index];
    final at =
        seconds == null ? '-' : formatDuration(Duration(seconds: seconds));
    print('${stage.name.en.padRight(14)}$at');
  }

  final state = result.finalState;
  print('\npurchases:     ${result.purchases}');
  print('tokens/s:      ${formatAmount(engine.productionPerSecond(state))}');
  print('run tokens:    ${formatAmount(state.runTokens)}');
  print('accuracy:      ${formatPercent(engine.accuracy(state))}');
  print('citations now: ${engine.citationsForPublishing(state)}');
  print('hardware:      ${state.generators}');
}
