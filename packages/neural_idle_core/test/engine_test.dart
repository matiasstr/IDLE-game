import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:test/test.dart';

const engine = GameEngine();

GameState withTokens(double tokens) =>
    GameState(tokens: tokens, runTokens: tokens, lifetimeTokens: tokens);

void main() {
  group('manual training', () {
    test('earns one token per step at the start', () {
      final state = engine.train(GameState.initial);
      expect(state.tokens, 1);
      expect(state.runTokens, 1);
      expect(state.lifetimeTokens, 1);
      expect(state.manualTrainings, 1);
    });

    test('is doubled by ReLU', () {
      expect(engine.tapValue(const GameState(upgrades: {'relu'})), 2);
    });

    test('earns a share of production with Adam', () {
      const state = GameState(generators: {'laptop': 10}, upgrades: {'adam'});
      // 10 laptops × 0.5 = 5 tokens/s, and Adam adds 2% of that per step.
      expect(engine.tapValue(state), closeTo(1.1, 1e-9));
    });
  });

  group('hardware', () {
    test('gets 15% pricier with each unit owned', () {
      expect(engine.generatorCost(GameState.initial, 'laptop'), 10);
      expect(
        engine.generatorCost(
            const GameState(generators: {'laptop': 1}), 'laptop'),
        12, // 11.5, rounded up
      );
      expect(
        engine.generatorCost(
            const GameState(generators: {'laptop': 10}), 'laptop'),
        41, // 10 × 1.15^10 = 40.46
      );
    });

    test('costs the same in bulk as one by one', () {
      var state = withTokens(1e6).copyWith(generators: {'laptop': 1});
      final bulk = engine.generatorCost(state, 'gaming_gpu', quantity: 10);
      var oneByOne = 0.0;
      for (var i = 0; i < 10; i++) {
        oneByOne += engine.generatorCost(state, 'gaming_gpu');
        state = engine.buyGenerator(state, 'gaming_gpu')!;
      }
      // Each single price is rounded up; the bulk price only once.
      expect(bulk, closeTo(oneByOne, 10));
    });

    test('reports how many units are affordable', () {
      final state = withTokens(5000);
      final count = engine.maxAffordable(state, 'laptop');
      expect(
        engine.generatorCost(state, 'laptop', quantity: count),
        lessThanOrEqualTo(5000),
      );
      expect(
        engine.generatorCost(state, 'laptop', quantity: count + 1),
        greaterThan(5000),
      );
      expect(engine.maxAffordable(withTokens(9), 'laptop'), 0);
    });

    test('is bought by paying its price', () {
      final state = engine.buyGenerator(withTokens(15), 'laptop')!;
      expect(state.tokens, 5);
      expect(state.owned('laptop'), 1);
      expect(engine.buyGenerator(withTokens(9), 'laptop'), isNull);
    });

    test('unlocks one tier at a time', () {
      const fresh = GameState.initial;
      expect(
        engine.generatorVisibility(fresh, 'laptop'),
        GeneratorVisibility.unlocked,
      );
      expect(
        engine.generatorVisibility(fresh, 'gaming_gpu'),
        GeneratorVisibility.teased,
      );
      expect(
        engine.generatorVisibility(fresh, 'mining_rig'),
        GeneratorVisibility.hidden,
      );
      expect(engine.buyGenerator(withTokens(1e9), 'gaming_gpu'), isNull);

      const withLaptop = GameState(generators: {'laptop': 1});
      expect(
        engine.generatorVisibility(withLaptop, 'gaming_gpu'),
        GeneratorVisibility.unlocked,
      );
      expect(
        engine.generatorVisibility(withLaptop, 'mining_rig'),
        GeneratorVisibility.teased,
      );
    });

    test('produces with upgrade and architecture bonuses', () {
      const state = GameState(
        generators: {'laptop': 4, 'gaming_gpu': 2},
        upgrades: {'mini_batches'},
      );
      // Laptops: 4 × 0.5 × 2 = 4. GPUs: 2 × 4 = 8.
      expect(engine.productionPerSecond(state), 12);
      expect(engine.generatorProduction(state, 'laptop'), 4);
      expect(engine.unitProduction(state, 'gaming_gpu'), 4);
      // The MLP stage multiplies everything by 1.2.
      expect(
        engine.productionPerSecond(state.copyWith(runTokens: 300)),
        closeTo(12 * 1.2, 1e-9),
      );
    });
  });

  group('research', () {
    test('appears once its condition is met', () {
      expect(engine.availableUpgrades(GameState.initial), isEmpty);
      expect(
        engine.availableUpgrades(withTokens(15)).map((u) => u.id),
        ['relu'],
      );
    });

    test('is bought once', () {
      final state = engine.buyUpgrade(withTokens(100), 'relu')!;
      expect(state.tokens, 60);
      expect(state.hasUpgrade('relu'), isTrue);
      expect(engine.buyUpgrade(state, 'relu'), isNull);
    });

    test('cannot be bought while locked', () {
      // Mini-batches needs 5 laptops.
      expect(engine.buyUpgrade(withTokens(1e9), 'mini_batches'), isNull);
    });

    test('describes its effect in both languages', () {
      const content = GameContent.standard;
      final miniBatches = engine.effectLabel(content.upgrade('mini_batches'));
      expect(miniBatches.en, 'Old Laptop ×2');
      expect(miniBatches.es, 'Notebook vieja ×2');
      expect(
        engine.effectLabel(content.upgrade('dropout')).es,
        'Toda la producción ×1,25',
      );
      expect(
        engine.effectLabel(content.upgrade('adam')).en,
        '+2% of tokens/s per step',
      );
      expect(
        engine.effectLabel(content.upgrade('relu')).resolve('es'),
        'Pasos de entrenamiento ×2',
      );
    });
  });

  group('architecture', () {
    test('starts as a perceptron guessing at random', () {
      expect(engine.architecture(GameState.initial).id, 'perceptron');
      expect(engine.accuracy(GameState.initial), closeTo(0.1, 1e-9));
      expect(engine.loss(GameState.initial), closeTo(2.302585, 1e-6));
    });

    test('evolves exactly at each threshold', () {
      for (final (index, stage) in kArchitectures.indexed) {
        expect(engine.stageIndex(GameState(runTokens: stage.threshold)), index);
        if (index > 0) {
          final justBefore = GameState(runTokens: stage.threshold - 1);
          expect(engine.stageIndex(justBefore), index - 1);
        }
      }
      expect(engine.nextArchitecture(const GameState(runTokens: 1e20)), isNull);
    });

    test('gets more accurate the more it trains', () {
      var previous = engine.accuracy(GameState.initial);
      for (var tokens = 10.0; tokens < 1e20; tokens *= 10) {
        final accuracy = engine.accuracy(GameState(runTokens: tokens));
        expect(accuracy, greaterThan(previous));
        expect(accuracy, lessThan(1));
        previous = accuracy;
      }
    });

    test('reports progress towards the next stage', () {
      expect(engine.stageProgress(GameState.initial), 0);
      expect(
        engine.stageProgress(const GameState(runTokens: 299)),
        closeTo(1, 0.01),
      );
      expect(engine.stageProgress(const GameState(runTokens: 1e20)), 1);
    });

    test('speaks lines from its current stage', () {
      expect(kPerceptronPhrases, contains(engine.phrase(GameState.initial, 3)));
      expect(
        kAgiPhrases,
        contains(engine.phrase(const GameState(runTokens: 1e13), -7)),
      );
    });
  });

  group('time', () {
    test('production accumulates over time', () {
      final state =
          engine.advance(const GameState(generators: {'laptop': 2}), 10);
      expect(state.tokens, closeTo(10, 1e-9));
      expect(state.playSeconds, 10);
    });

    test('a new stage boosts production from the moment it is reached', () {
      // 100 laptops make 50 tokens/s: MLP (300 tokens) after 6 s, then ×1.2.
      final state =
          engine.advance(const GameState(generators: {'laptop': 100}), 10);
      expect(state.runTokens, closeTo(300 + 4 * 60, 1e-6));
      expect(engine.architecture(state).id, 'mlp');
    });

    test('one long step equals many short ones', () {
      const start = GameState(generators: {'server_rack': 30, 'laptop': 10});
      final once = engine.advance(start, 3600);
      var many = start;
      for (var i = 0; i < 3600; i++) {
        many = engine.advance(many, 1);
      }
      expect(once.runTokens, closeTo(many.runTokens, many.runTokens * 1e-9));
      expect(engine.stageIndex(once), engine.stageIndex(many));
    });

    test('offline progress is capped and matches online production', () {
      const start = GameState(generators: {'laptop': 2});
      final result =
          engine.applyOfflineProgress(start, const Duration(days: 3));
      expect(result.credited, const Duration(hours: 8));
      final online = engine.advance(start, 8 * 3600);
      expect(result.state.runTokens, closeTo(online.runTokens, 1e-6));
      expect(result.tokensEarned, closeTo(online.lifetimeTokens, 1e-6));
      expect(result.stagesGained, 2); // Perceptron → MLP → CNN.
      expect(result.state.playSeconds, 0);
    });

    test('a clock moved backwards credits nothing', () {
      final result = engine.applyOfflineProgress(
        const GameState(generators: {'laptop': 2}),
        const Duration(hours: -1),
      );
      expect(result.credited, Duration.zero);
      expect(result.tokensEarned, 0);
    });
  });

  group('publishing a paper', () {
    test('needs a Transformer', () {
      expect(engine.canPublish(const GameState(runTokens: 4.9e7)), isFalse);
      expect(
          engine.citationsForPublishing(const GameState(runTokens: 5e7)), 10);
      expect(engine.publishPaper(withTokens(1000)), isNull);
    });

    test('restarts the run but keeps citations and stats', () {
      const state = GameState(
        tokens: 1e9,
        runTokens: 4e8,
        lifetimeTokens: 5e8,
        citations: 3,
        generators: {'laptop': 50},
        upgrades: {'relu'},
        manualTrainings: 99,
        playSeconds: 120,
      );
      final after = engine.publishPaper(state)!;
      expect(after.tokens, 0);
      expect(after.runTokens, 0);
      expect(after.generators, isEmpty);
      expect(after.upgrades, isEmpty);
      expect(after.lifetimeTokens, 5e8);
      // 4e8 is 8× the Transformer threshold: 10 × ∛8 = 20 citations.
      expect(after.citations, 3 + 20);
      expect(after.papersPublished, 1);
      expect(after.manualTrainings, 99);
      expect(after.playSeconds, 120);
    });

    test('citations boost production', () {
      const state = GameState(generators: {'laptop': 10}, citations: 50);
      // 50 citations × 2% = +100%.
      expect(engine.productionPerSecond(state), closeTo(10, 1e-9));
    });
  });
}
