import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:test/test.dart';

void main() {
  const content = GameContent.standard;

  test('ids are unique', () {
    for (final ids in [
      content.generators.map((g) => g.id),
      content.upgrades.map((u) => u.id),
      content.architectures.map((a) => a.id),
    ]) {
      expect(ids.toSet(), hasLength(ids.length));
    }
  });

  test('architectures start at zero and keep growing', () {
    final stages = content.architectures;
    expect(stages.first.threshold, 0);
    for (var i = 1; i < stages.length; i++) {
      expect(stages[i].threshold, greaterThan(stages[i - 1].threshold));
      expect(stages[i].multiplier, greaterThan(stages[i - 1].multiplier));
    }
    for (final stage in stages) {
      expect(stage.layers, isNotEmpty);
      expect(stage.layers.every((neurons) => neurons > 0), isTrue);
      expect(stage.phrases, isNotEmpty);
    }
    expect(content.publishStage, lessThan(stages.length));
  });

  test('each hardware tier is pricier and slower to pay back', () {
    final tiers = content.generators;
    for (var i = 1; i < tiers.length; i++) {
      final previous = tiers[i - 1];
      final tier = tiers[i];
      expect(tier.baseCost, greaterThan(previous.baseCost));
      expect(
        tier.baseCost / tier.baseProduction,
        greaterThan(previous.baseCost / previous.baseProduction),
        reason: '${tier.id} should pay back slower than ${previous.id}',
      );
    }
  });

  test('research points at existing hardware and stages', () {
    for (final upgrade in content.upgrades) {
      if (upgrade.effect case GeneratorMultiplier(:final generatorId)) {
        expect(content.hasGenerator(generatorId), isTrue, reason: upgrade.id);
      }
      switch (upgrade.unlock) {
        case GeneratorOwnedAtLeast(:final generatorId):
          expect(content.hasGenerator(generatorId), isTrue, reason: upgrade.id);
        case StageAtLeast(:final stage):
          expect(stage, lessThan(content.architectures.length));
        case RunTokensAtLeast():
          break;
      }
    }
  });

  test('every text is translated', () {
    final texts = [
      for (final g in content.generators) ...[g.name, g.description],
      for (final u in content.upgrades) ...[u.name, u.description],
      for (final a in content.architectures) ...[
        a.name,
        a.description,
        ...a.phrases,
      ],
    ];
    for (final text in texts) {
      expect(text.en.trim(), isNotEmpty);
      expect(text.es.trim(), isNotEmpty, reason: text.en);
    }
  });
}
