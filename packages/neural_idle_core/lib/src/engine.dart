import 'dart:math' as math;

import 'content/architectures.dart';
import 'content/game_content.dart';
import 'content/upgrades.dart';
import 'format.dart';
import 'game_state.dart';
import 'localized_text.dart';

/// How a generator shows up in the shop.
enum GeneratorVisibility {
  /// Can be bought, if affordable.
  unlocked,

  /// The next one to unlock: shown as a mystery card.
  teased,

  /// Not shown yet.
  hidden,
}

/// The result of crediting the time the player was away.
class OfflineProgress {
  const OfflineProgress({
    required this.state,
    required this.credited,
    required this.tokensEarned,
    required this.stagesGained,
  });

  final GameState state;

  /// The part of the absence that was credited (capped).
  final Duration credited;

  final double tokensEarned;

  /// Architecture stages reached while away.
  final int stagesGained;
}

/// The rules of Neural Idle.
///
/// Stateless: every method takes a [GameState] and returns a value or a new
/// state, so the whole game can be unit-tested and simulated without Flutter.
class GameEngine {
  const GameEngine([this.content = GameContent.standard]);

  final GameContent content;

  // --------------------------------------------------------------- stages

  /// Index of the current architecture in [GameContent.architectures].
  int stageIndex(GameState state) {
    final stages = content.architectures;
    var index = 0;
    while (index + 1 < stages.length &&
        state.runTokens >= stages[index + 1].threshold) {
      index++;
    }
    return index;
  }

  ArchitectureDef architecture(GameState state) =>
      content.architectures[stageIndex(state)];

  /// The next architecture, or null at the final stage.
  ArchitectureDef? nextArchitecture(GameState state) {
    final next = stageIndex(state) + 1;
    return next < content.architectures.length
        ? content.architectures[next]
        : null;
  }

  /// Progress towards the next architecture, from 0 to 1.
  ///
  /// Measured on a log scale so the bar moves at a steady pace even though
  /// production grows exponentially.
  double stageProgress(GameState state) {
    final next = nextArchitecture(state);
    if (next == null) return 1;
    final from = math.log(architecture(state).threshold + 1);
    final to = math.log(next.threshold + 1);
    final now = math.log(state.runTokens + 1);
    return ((now - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// Model accuracy: 10% untrained (a random guess among ten classes),
  /// approaching 100% without ever reaching it.
  double accuracy(GameState state) {
    final ordersOfMagnitude = math.log(state.runTokens + 1) / math.ln10;
    return 1 - 0.9 * math.exp(-ordersOfMagnitude / 3);
  }

  /// Cross-entropy loss for the current [accuracy]: ln(10) ≈ 2.30 untrained.
  double loss(GameState state) => -math.log(accuracy(state));

  /// A line for the AI to say at its current stage; [seed] picks which.
  LocalizedText phrase(GameState state, int seed) {
    final phrases = architecture(state).phrases;
    return phrases[seed.abs() % phrases.length];
  }

  // -------------------------------------------------------------- economy

  /// Price of the next [quantity] units of a generator.
  double generatorCost(
    GameState state,
    String generatorId, {
    int quantity = 1,
  }) {
    final def = content.generator(generatorId);
    final growth = def.costGrowth;
    final first = def.baseCost * math.pow(growth, state.owned(generatorId));
    if (quantity <= 1) return _ceil(first);
    // Geometric series: first · (growth^quantity − 1) / (growth − 1).
    return _ceil(first * (math.pow(growth, quantity) - 1) / (growth - 1));
  }

  /// How many units of a generator the player can buy right now.
  int maxAffordable(GameState state, String generatorId) {
    if (generatorCost(state, generatorId) > state.tokens) return 0;
    final def = content.generator(generatorId);
    final growth = def.costGrowth;
    final first = def.baseCost * math.pow(growth, state.owned(generatorId));
    // Invert the geometric series, then correct for rounding.
    var count = math.max(
      1,
      (math.log(state.tokens * (growth - 1) / first + 1) / math.log(growth))
          .floor(),
    );
    while (count > 1 &&
        generatorCost(state, generatorId, quantity: count) > state.tokens) {
      count--;
    }
    while (generatorCost(state, generatorId, quantity: count + 1) <=
        state.tokens) {
      count++;
    }
    return count;
  }

  /// Bonus from published papers: +[GameContent.citationBonus] per citation.
  double prestigeMultiplier(GameState state) =>
      1 + state.citations * content.citationBonus;

  /// Multiplier applied to all hardware: architecture × research × prestige.
  double globalMultiplier(GameState state) {
    var multiplier = architecture(state).multiplier * prestigeMultiplier(state);
    for (final upgrade in content.upgrades) {
      final effect = upgrade.effect;
      if (effect is GlobalMultiplier && state.hasUpgrade(upgrade.id)) {
        multiplier *= effect.factor;
      }
    }
    return multiplier;
  }

  /// Tokens per second produced by one unit of a generator, all bonuses
  /// included.
  double unitProduction(GameState state, String generatorId) =>
      content.generator(generatorId).baseProduction *
      _generatorMultiplier(state, generatorId) *
      globalMultiplier(state);

  /// Tokens per second produced by all units of a generator.
  double generatorProduction(GameState state, String generatorId) =>
      state.owned(generatorId) * unitProduction(state, generatorId);

  /// Total tokens per second from hardware.
  double productionPerSecond(GameState state) {
    var total = 0.0;
    for (final generator in content.generators) {
      final owned = state.owned(generator.id);
      if (owned == 0) continue;
      total += owned *
          generator.baseProduction *
          _generatorMultiplier(state, generator.id);
    }
    return total * globalMultiplier(state);
  }

  /// Tokens earned by one manual training step.
  double tapValue(GameState state) {
    var multiplier = 1.0;
    var share = 0.0;
    for (final upgrade in content.upgrades) {
      if (!state.hasUpgrade(upgrade.id)) continue;
      switch (upgrade.effect) {
        case TapMultiplier(:final factor):
          multiplier *= factor;
        case TapProductionShare(share: final productionShare):
          share += productionShare;
        case GeneratorMultiplier() || GlobalMultiplier():
          break;
      }
    }
    return content.baseTapValue * multiplier * prestigeMultiplier(state) +
        productionPerSecond(state) * share;
  }

  GeneratorVisibility generatorVisibility(
    GameState state,
    String generatorId,
  ) {
    final index = _generatorIndex(generatorId);
    if (index == 0 || state.owned(generatorId) > 0) {
      return GeneratorVisibility.unlocked;
    }
    final previous = content.generators[index - 1].id;
    if (state.owned(previous) > 0) return GeneratorVisibility.unlocked;
    return generatorVisibility(state, previous) == GeneratorVisibility.unlocked
        ? GeneratorVisibility.teased
        : GeneratorVisibility.hidden;
  }

  bool isUpgradeUnlocked(GameState state, UpgradeDef upgrade) =>
      switch (upgrade.unlock) {
        RunTokensAtLeast(:final amount) => state.runTokens >= amount,
        GeneratorOwnedAtLeast(:final generatorId, :final count) =>
          state.owned(generatorId) >= count,
        StageAtLeast(:final stage) => stageIndex(state) >= stage,
      };

  /// Research the player can see: unlocked, not bought yet, cheapest first.
  List<UpgradeDef> availableUpgrades(GameState state) => [
        for (final upgrade in content.upgrades)
          if (!state.hasUpgrade(upgrade.id) &&
              isUpgradeUnlocked(state, upgrade))
            upgrade,
      ]..sort((a, b) => a.cost.compareTo(b.cost));

  /// Short summary of what an upgrade does, e.g. "Old Laptop ×2".
  LocalizedText effectLabel(UpgradeDef upgrade) {
    String factor(double value, String languageCode) =>
        formatFactor(value, languageCode: languageCode);
    return switch (upgrade.effect) {
      TapMultiplier(factor: final f) => LocalizedText(
          en: 'Training steps ×${factor(f, 'en')}',
          es: 'Pasos de entrenamiento ×${factor(f, 'es')}',
        ),
      TapProductionShare(:final share) => LocalizedText(
          en: '+${factor(_percent(share), 'en')}% of tokens/s per step',
          es: '+${factor(_percent(share), 'es')}% de tokens/s por paso',
        ),
      GeneratorMultiplier(:final generatorId, factor: final f) => LocalizedText(
          en: '${content.generator(generatorId).name.en} ×${factor(f, 'en')}',
          es: '${content.generator(generatorId).name.es} ×${factor(f, 'es')}',
        ),
      GlobalMultiplier(factor: final f) => LocalizedText(
          en: 'All production ×${factor(f, 'en')}',
          es: 'Toda la producción ×${factor(f, 'es')}',
        ),
    };
  }

  // -------------------------------------------------------------- actions

  /// One manual training step (a tap on the train button).
  GameState train(GameState state) => state
      .earn(tapValue(state))
      .copyWith(manualTrainings: state.manualTrainings + 1);

  /// Buys [quantity] units of a generator, or returns null if it is locked
  /// or unaffordable.
  GameState? buyGenerator(
    GameState state,
    String generatorId, {
    int quantity = 1,
  }) {
    if (quantity < 1 ||
        generatorVisibility(state, generatorId) !=
            GeneratorVisibility.unlocked) {
      return null;
    }
    final cost = generatorCost(state, generatorId, quantity: quantity);
    if (cost > state.tokens) return null;
    return state.copyWith(
      tokens: state.tokens - cost,
      generators: {
        ...state.generators,
        generatorId: state.owned(generatorId) + quantity,
      },
    );
  }

  /// Buys a research upgrade, or returns null if it is not available or
  /// unaffordable.
  GameState? buyUpgrade(GameState state, String upgradeId) {
    final upgrade = content.upgrade(upgradeId);
    if (state.hasUpgrade(upgradeId) ||
        !isUpgradeUnlocked(state, upgrade) ||
        upgrade.cost > state.tokens) {
      return null;
    }
    return state.copyWith(
      tokens: state.tokens - upgrade.cost,
      upgrades: {...state.upgrades, upgradeId},
    );
  }

  /// Runs the hardware for [seconds] of play time.
  GameState advance(GameState state, double seconds) {
    if (!(seconds > 0)) return state;
    return _produce(state, seconds)
        .copyWith(playSeconds: state.playSeconds + seconds);
  }

  /// Credits the time the player was away, up to [GameContent.offlineCap].
  OfflineProgress applyOfflineProgress(GameState state, Duration away) {
    final credited = away.isNegative
        ? Duration.zero
        : (away > content.offlineCap ? content.offlineCap : away);
    final after = _produce(state, credited.inMilliseconds / 1000);
    return OfflineProgress(
      state: after,
      credited: credited,
      tokensEarned: after.lifetimeTokens - state.lifetimeTokens,
      stagesGained: stageIndex(after) - stageIndex(state),
    );
  }

  // ------------------------------------------------------------- prestige

  /// Citations a paper would earn right now (0 before
  /// [GameContent.publishStage]).
  int citationsForPublishing(GameState state) {
    final reference = content.architectures[content.publishStage].threshold;
    if (state.runTokens < reference) return 0;
    final ratio = state.runTokens / reference;
    // The epsilon keeps exact cubes exact: pow(8, 1/3) = 1.9999999999999998.
    return (content.citationScale * math.pow(ratio, 1 / 3) + 1e-9).floor();
  }

  bool canPublish(GameState state) => citationsForPublishing(state) > 0;

  /// Publishes a paper: the run restarts from scratch, but the citations
  /// earned boost all future production. Returns null if not possible yet.
  GameState? publishPaper(GameState state) {
    final earned = citationsForPublishing(state);
    if (earned == 0) return null;
    return GameState(
      lifetimeTokens: state.lifetimeTokens,
      citations: state.citations + earned,
      manualTrainings: state.manualTrainings,
      papersPublished: state.papersPublished + 1,
      playSeconds: state.playSeconds,
    );
  }

  // -------------------------------------------------------------- helpers

  /// Production over [seconds], exact even for long spans: production is
  /// constant between stages, so the span is split at each stage threshold
  /// and the new multiplier applies from that moment on.
  GameState _produce(GameState state, double seconds) {
    var current = state;
    var remaining = seconds;
    while (remaining > 0) {
      final rate = productionPerSecond(current);
      if (rate <= 0) break;
      final next = nextArchitecture(current);
      final untilNext = next == null
          ? double.infinity
          : (next.threshold - current.runTokens) / rate;
      if (untilNext >= remaining) return current.earn(rate * remaining);
      final missing = next!.threshold - current.runTokens;
      // Land exactly on the threshold so floating-point error can't stall.
      current = current.earn(missing).copyWith(runTokens: next.threshold);
      remaining -= untilNext;
    }
    return current;
  }

  double _generatorMultiplier(GameState state, String generatorId) {
    var multiplier = 1.0;
    for (final upgrade in content.upgrades) {
      final effect = upgrade.effect;
      if (effect is GeneratorMultiplier &&
          effect.generatorId == generatorId &&
          state.hasUpgrade(upgrade.id)) {
        multiplier *= effect.factor;
      }
    }
    return multiplier;
  }

  int _generatorIndex(String generatorId) {
    final index = content.generators.indexWhere((g) => g.id == generatorId);
    if (index < 0) {
      throw ArgumentError.value(
          generatorId, 'generatorId', 'Unknown generator');
    }
    return index;
  }
}

/// 0.025 → 2.5, without binary noise such as 2.5000000000000004.
double _percent(double share) => (share * 10000).round() / 100;

/// Rounds a price up to whole tokens, ignoring floating-point noise.
double _ceil(num value) => (value - value.abs() * 1e-12).ceilToDouble();
