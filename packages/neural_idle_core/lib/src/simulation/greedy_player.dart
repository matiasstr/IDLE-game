import '../engine.dart';
import '../game_state.dart';

/// Outcome of a simulated run.
class SimulationResult {
  const SimulationResult({
    required this.finalState,
    required this.stageReachedAt,
    required this.purchases,
  });

  final GameState finalState;

  /// Seconds into the run at which each stage index was first reached.
  final Map<int, int> stageReachedAt;

  final int purchases;
}

/// A deterministic bot that plays greedily: it trains by hand at a steady
/// pace and keeps buying whatever pays for itself the soonest.
///
/// Used to tune the economy (`dart run tool/simulate.dart`) and to guard
/// the pacing in tests, so a balance change can't silently make the first
/// minutes boring for someone trying the game from a portfolio link.
class GreedyPlayer {
  const GreedyPlayer({
    this.engine = const GameEngine(),
    this.tapsPerSecond = 4,
  });

  final GameEngine engine;
  final int tapsPerSecond;

  /// Plays for [duration], deciding every [step] seconds.
  SimulationResult play(
    Duration duration, {
    GameState start = GameState.initial,
    int step = 1,
  }) {
    var state = start;
    var purchases = 0;
    var stage = engine.stageIndex(state);
    final reached = <int, int>{stage: 0};

    for (var time = step; time <= duration.inSeconds; time += step) {
      for (var i = 0; i < tapsPerSecond * step; i++) {
        state = engine.train(state);
      }
      state = engine.advance(state, step.toDouble());
      for (var next = _bestPurchase(state);
          next != null;
          next = _bestPurchase(state)) {
        state = next;
        purchases++;
      }
      final current = engine.stageIndex(state);
      for (; stage < current; stage++) {
        reached[stage + 1] = time;
      }
    }
    return SimulationResult(
      finalState: state,
      stageReachedAt: reached,
      purchases: purchases,
    );
  }

  /// Tokens per second from hardware plus manual training.
  double _income(GameState state) =>
      engine.productionPerSecond(state) +
      tapsPerSecond * engine.tapValue(state);

  /// The state after buying the best option, or null to keep saving for it.
  ///
  /// Options are ranked by seconds until they pay for themselves, counting
  /// the wait until they become affordable.
  GameState? _bestPurchase(GameState state) {
    final income = _income(state);
    GameState? Function()? bestBuy;
    var bestScore = double.infinity;
    var bestAffordable = false;

    void consider(
      double cost,
      GameState withItem,
      GameState? Function() buy,
    ) {
      final gain = _income(withItem) - income;
      if (gain <= 0) return;
      final wait = cost > state.tokens ? (cost - state.tokens) / income : 0.0;
      final score = cost / gain + wait;
      if (score < bestScore) {
        bestScore = score;
        bestBuy = buy;
        bestAffordable = cost <= state.tokens;
      }
    }

    for (final generator in engine.content.generators) {
      if (engine.generatorVisibility(state, generator.id) !=
          GeneratorVisibility.unlocked) {
        continue;
      }
      consider(
        engine.generatorCost(state, generator.id),
        state.copyWith(generators: {
          ...state.generators,
          generator.id: state.owned(generator.id) + 1,
        }),
        () => engine.buyGenerator(state, generator.id),
      );
    }
    for (final upgrade in engine.availableUpgrades(state)) {
      consider(
        upgrade.cost,
        state.copyWith(upgrades: {...state.upgrades, upgrade.id}),
        () => engine.buyUpgrade(state, upgrade.id),
      );
    }
    return bestAffordable ? bestBuy?.call() : null;
  }
}
