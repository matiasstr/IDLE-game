import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle_core/neural_idle_core.dart';

/// First-run hints, in the order a new player meets them.
enum OnboardingStep {
  /// Tap the train button for the first tokens.
  train,

  /// The first hardware is affordable: buy it.
  buyHardware,

  /// Hardware is running: the network evolves at the next threshold.
  evolve,

  /// A research upgrade is affordable.
  research,
}

/// The hint a player should see now, or null.
///
/// Hints belong to the first run only. Each one shows while its moment lasts
/// (it ends by itself once the player does the thing) unless the player
/// dismissed it.
OnboardingStep? onboardingStep(
  GameEngine engine,
  GameState game,
  Set<OnboardingStep> dismissed,
) {
  if (game.papersPublished > 0 || game.citations > 0) return null;
  bool open(OnboardingStep step) => !dismissed.contains(step);

  if (game.manualTrainings == 0 && game.lifetimeTokens == 0) {
    return open(OnboardingStep.train) ? OnboardingStep.train : null;
  }
  final first = engine.content.generators.first.id;
  if (game.owned(first) == 0) {
    final affordable = game.tokens >= engine.generatorCost(game, first);
    return affordable && open(OnboardingStep.buyHardware)
        ? OnboardingStep.buyHardware
        : null;
  }
  if (engine.stageIndex(game) == 0) {
    return open(OnboardingStep.evolve) ? OnboardingStep.evolve : null;
  }
  if (game.upgrades.isEmpty &&
      engine.availableUpgrades(game).any((u) => game.tokens >= u.cost)) {
    return open(OnboardingStep.research) ? OnboardingStep.research : null;
  }
  return null;
}

/// Hints the player dismissed, kept across sessions.
final onboardingProvider =
    NotifierProvider<OnboardingController, Set<OnboardingStep>>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<Set<OnboardingStep>> {
  static const key = 'neural_idle.onboarding';

  @override
  Set<OnboardingStep> build() {
    final names = ref.watch(sharedPreferencesProvider).getStringList(key);
    final byName = OnboardingStep.values.asNameMap();
    return {for (final name in names ?? const <String>[]) ?byName[name]};
  }

  void dismiss(OnboardingStep step) {
    if (state.contains(step)) return;
    state = {...state, step};
    unawaited(
      ref.read(sharedPreferencesProvider).setStringList(key, [
        for (final s in state) s.name,
      ]),
    );
  }
}
