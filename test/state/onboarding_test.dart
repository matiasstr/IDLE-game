import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle/state/onboarding.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const engine = GameEngine();
  OnboardingStep? step(
    GameState game, [
    Set<OnboardingStep> dismissed = const {},
  ]) => onboardingStep(engine, game, dismissed);

  test('a new player is walked through train, hardware, evolve, research', () {
    expect(step(GameState.initial), OnboardingStep.train);

    // Trained a bit, but the laptop (10 tokens) is not affordable yet.
    const trained = GameState(
      tokens: 4,
      runTokens: 4,
      lifetimeTokens: 4,
      manualTrainings: 4,
    );
    expect(step(trained), isNull);
    expect(
      step(trained.copyWith(tokens: 10, runTokens: 10, lifetimeTokens: 10)),
      OnboardingStep.buyHardware,
    );

    // Hardware bought: until the MLP, point at the next evolution.
    final running = trained.copyWith(generators: {'laptop': 1});
    expect(step(running), OnboardingStep.evolve);

    // Evolved, with research affordable and none bought yet.
    final evolved = running.copyWith(
      tokens: 1e6,
      runTokens: 400,
      lifetimeTokens: 400,
      generators: {'laptop': 10},
    );
    expect(engine.stageIndex(evolved), 1);
    expect(engine.availableUpgrades(evolved), isNotEmpty);
    expect(step(evolved), OnboardingStep.research);
    final upgrade = engine.availableUpgrades(evolved).first.id;
    expect(step(evolved.copyWith(upgrades: {upgrade})), isNull);
  });

  test('dismissed hints stay away; later runs get none', () {
    expect(step(GameState.initial, {OnboardingStep.train}), isNull);
    expect(
      step(const GameState(papersPublished: 1)),
      isNull,
      reason: 'after a paper the player knows the game',
    );
    expect(step(const GameState(citations: 3)), isNull);
  });

  test('dismissals are saved and survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer create() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    final first = create();
    first.read(onboardingProvider.notifier)
      ..dismiss(OnboardingStep.train)
      ..dismiss(OnboardingStep.train);
    expect(first.read(onboardingProvider), {OnboardingStep.train});
    expect(create().read(onboardingProvider), {OnboardingStep.train});

    await prefs.setStringList(OnboardingController.key, ['nope', 'evolve']);
    expect(create().read(onboardingProvider), {OnboardingStep.evolve});
  });

  test('the hardware hint counts the units a tap would buy', () {
    const twelve = GameState(
      tokens: 12,
      runTokens: 12,
      lifetimeTokens: 12,
      manualTrainings: 12,
    );
    expect(step(twelve), OnboardingStep.buyHardware);
    expect(onboardingStep(engine, twelve, const {}, buyQuantity: 10), isNull);
  });
}
