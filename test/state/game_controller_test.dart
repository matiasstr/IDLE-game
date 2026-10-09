import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle/state/game_controller.dart';
import 'package:neural_idle/state/game_loop.dart';

import 'dart:convert';

import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.utc(2026, 10, 9, 12);

Future<(ProviderContainer, SharedPreferences)> createContainer({
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

String saveOf(GameState state, DateTime savedAt) =>
    const SaveCodec().encode(state, savedAt: savedAt);

void main() {
  test('a new player starts from scratch with nothing to report', () async {
    final (container, _) = await createContainer();
    final session = container.read(gameControllerProvider);
    expect(session.state, GameState.initial);
    expect(session.offline, isNull);
  });

  test('training and buying go through the engine', () async {
    final (container, _) = await createContainer();
    final controller = container.read(gameControllerProvider.notifier);
    for (var i = 0; i < 10; i++) {
      controller.train();
    }
    expect(container.read(gameControllerProvider).state.tokens, 10);
    expect(controller.buyGenerator('laptop'), isTrue);
    expect(controller.buyGenerator('laptop'), isFalse, reason: 'broke');
    final state = container.read(gameControllerProvider).state;
    expect(state.owned('laptop'), 1);
    expect(state.tokens, 0);
    expect(state.manualTrainings, 10);
  });

  test('autosaves every 10 seconds of play', () async {
    final (container, prefs) = await createContainer();
    final controller = container.read(gameControllerProvider.notifier)..train();
    controller.tick(9);
    expect(prefs.getString(GameController.saveKey), isNull);
    controller.tick(1);
    final saved = const SaveCodec().decode(
      prefs.getString(GameController.saveKey)!,
    )!;
    expect(saved.state.manualTrainings, 1);
    expect(saved.savedAt, now);
  });

  test('loading a save credits the time away and reports it once', () async {
    const game = GameState(generators: {'laptop': 2});
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          game,
          now.subtract(const Duration(hours: 3)),
        ),
      },
    );
    final session = container.read(gameControllerProvider);
    final offline = session.offline!;
    expect(offline.credited, const Duration(hours: 3));
    expect(offline.tokensEarned, greaterThan(3 * 3600));
    expect(session.state.tokens, offline.tokensEarned);

    container.read(gameControllerProvider.notifier).dismissOffline();
    expect(container.read(gameControllerProvider).offline, isNull);
  });

  test('short absences are credited silently', () async {
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          const GameState(generators: {'laptop': 2}),
          now.subtract(const Duration(seconds: 30)),
        ),
      },
    );
    final session = container.read(gameControllerProvider);
    expect(session.offline, isNull);
    expect(session.state.tokens, closeTo(30, 1e-6));
  });

  test('a corrupted save starts a new game instead of crashing', () async {
    final (container, _) = await createContainer(
      preferences: {GameController.saveKey: '{not json'},
    );
    expect(container.read(gameControllerProvider).state, GameState.initial);
  });

  test('resuming from the background credits the gap', () async {
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          const GameState(generators: {'laptop': 2}),
          now,
        ),
      },
    );
    container
        .read(gameControllerProvider.notifier)
        .resumeAfter(const Duration(minutes: 5));
    final session = container.read(gameControllerProvider);
    expect(session.offline?.credited, const Duration(minutes: 5));
    expect(session.state.tokens, closeTo(300, 1e-6));
  });

  test('exported saves import back; garbage is rejected', () async {
    final (container, _) = await createContainer();
    final controller = container.read(gameControllerProvider.notifier)
      ..train()
      ..train();
    final exported = controller.exportSave();
    controller.resetProgress();
    expect(container.read(gameControllerProvider).state, GameState.initial);

    expect(controller.importSave('  $exported\n'), isTrue);
    expect(container.read(gameControllerProvider).state.manualTrainings, 2);
    expect(controller.importSave('nope'), isFalse);
    expect(container.read(gameControllerProvider).state.manualTrainings, 2);
  });

  test('publishing a paper needs a Transformer and keeps citations', () async {
    final (container, prefs) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          const GameState(tokens: 5e7, runTokens: 4e8, lifetimeTokens: 4e8),
          now,
        ),
      },
    );
    final controller = container.read(gameControllerProvider.notifier);
    expect(controller.publishPaper(), isTrue);
    final state = container.read(gameControllerProvider).state;
    expect(state.citations, 20);
    expect(state.tokens, 0);
    expect(state.papersPublished, 1);
    expect(prefs.getString(GameController.saveKey), isNotNull);
    expect(controller.publishPaper(), isFalse, reason: 'the new run is fresh');
  });

  test('the loss chart samples once per second and marks evolutions', () async {
    final (container, prefs) = await createContainer(
      preferences: {
        // 290 run tokens and 10 tokens/s: MLP (300) arrives in the 1st second.
        GameController.saveKey: saveOf(
          const GameState(
            runTokens: 290,
            lifetimeTokens: 290,
            generators: {'laptop': 20},
          ),
          now,
        ),
      },
    );
    final controller = container.read(gameControllerProvider.notifier);
    final loss = container.read(lossHistoryProvider);
    for (var i = 0; i < 30; i++) {
      controller.tick(0.1);
    }
    expect(loss.length, 3);
    expect(loss.markers.map((m) => m.label), ['MLP']);
    expect(
      loss.latest,
      closeTo(
        controller.engine.loss(container.read(gameControllerProvider).state),
        0.05,
      ),
    );

    controller.save();
    final saved = LossHistory.fromJson(
      jsonDecode(prefs.getString(GameController.lossKey)!)
          as Map<String, Object?>,
    );
    expect(saved.length, 3);
  });

  test('publishing a paper starts a new loss chart', () async {
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          const GameState(runTokens: 4e8, lifetimeTokens: 4e8),
          now,
        ),
      },
    );
    final controller = container.read(gameControllerProvider.notifier);
    final loss = container.read(lossHistoryProvider)
      ..add(0.5)
      ..add(0.4);
    expect(loss.length, 2);
    controller.publishPaper();
    expect(loss.length, 0);
  });

  test('a corrupt saved chart starts fresh', () async {
    final (container, _) = await createContainer(
      preferences: {GameController.lossKey: '{"points": "nope"'},
    );
    expect(container.read(lossHistoryProvider).length, 0);
  });

  testWidgets('the game loop advances the engine while on screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GameController.saveKey: saveOf(
        const GameState(generators: {'laptop': 2}),
        DateTime.now(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GameLoop(child: SizedBox()),
      ),
    );
    final before = container.read(gameControllerProvider).state.tokens;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final after = container.read(gameControllerProvider).state.tokens;
    // 1 token/s for ~1 s of frames.
    expect(after - before, closeTo(1, 0.15));

    // A long gap between frames counts as time away.
    await tester.pump(const Duration(minutes: 2));
    final session = container.read(gameControllerProvider);
    expect(session.offline?.credited, const Duration(minutes: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
