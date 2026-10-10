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
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock ?? () => now),
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

  test('buying max spends on as many units as the tokens allow', () async {
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(const GameState(tokens: 100), now),
      },
    );
    final controller = container.read(gameControllerProvider.notifier);
    final expected = controller.engine.maxAffordable(
      container.read(gameControllerProvider).state,
      'laptop',
    );
    expect(expected, greaterThan(1));
    expect(controller.buyMax('laptop'), isTrue);
    final state = container.read(gameControllerProvider).state;
    expect(state.owned('laptop'), expected);
    expect(
      controller.engine.generatorCost(state, 'laptop'),
      greaterThan(state.tokens),
      reason: 'not even one more is affordable',
    );
    expect(controller.buyMax('laptop'), isFalse);
    expect(controller.buyMax('gaming_gpu'), isFalse, reason: 'locked');
  });

  test('autosaves every 10 seconds of play', () async {
    final (container, prefs) = await createContainer();
    final controller = container.read(gameControllerProvider.notifier)..train();
    controller.tick(9);
    expect(prefs.getString(GameController.saveKey), isNull);
    controller.tick(1);
    await pumpEventQueue();
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
    await container
        .read(gameControllerProvider.notifier)
        .resumeAfter(const Duration(minutes: 5));
    final session = container.read(gameControllerProvider);
    expect(session.offline?.credited, const Duration(minutes: 5));
    expect(session.state.tokens, closeTo(300, 1e-6));
  });

  test('evolutions while away are all marked on the loss chart', () async {
    // 60 tokens/s for 5 minutes: past the MLP (300) and the CNN (15000).
    const game = GameState(
      runTokens: 290,
      lifetimeTokens: 290,
      generators: {'laptop': 120},
    );
    final (container, _) = await createContainer(
      preferences: {
        GameController.saveKey: saveOf(
          game,
          now.subtract(const Duration(minutes: 5)),
        ),
      },
    );
    container.read(gameControllerProvider);
    final loss = container.read(lossHistoryProvider);
    expect(loss.markers.map((m) => m.label), ['MLP', 'CNN']);
    expect(loss.length, 1);

    // The same when resuming from the background.
    final (resumed, _) = await createContainer(
      preferences: {GameController.saveKey: saveOf(game, now)},
    );
    await resumed
        .read(gameControllerProvider.notifier)
        .resumeAfter(const Duration(minutes: 5));
    expect(resumed.read(lossHistoryProvider).markers.map((m) => m.label), [
      'MLP',
      'CNN',
    ]);
  });

  group('another tab or window playing the same save', () {
    test('its newer save wins over an autosave', () async {
      var clock = now;
      final (container, prefs) = await createContainer(
        preferences: {
          GameController.saveKey: saveOf(
            const GameState(generators: {'laptop': 2}),
            now,
          ),
        },
        clock: () => clock,
      );
      final controller = container.read(gameControllerProvider.notifier);
      // The other tab saved 5 seconds in, with more laptops.
      await prefs.setString(
        GameController.saveKey,
        saveOf(
          const GameState(tokens: 100, generators: {'laptop': 7}),
          now.add(const Duration(seconds: 5)),
        ),
      );
      clock = now.add(const Duration(seconds: 10));
      controller.tick(10);
      await pumpEventQueue();

      // Its game plus the 5 seconds since it saved, never both games' time.
      final state = container.read(gameControllerProvider).state;
      expect(state.owned('laptop'), 7);
      expect(state.tokens, closeTo(100 + 7 * 0.5 * 5, 1e-6));
      final saved = const SaveCodec().decode(
        prefs.getString(GameController.saveKey)!,
      )!;
      expect(saved.savedAt, clock);
      expect(saved.state.owned('laptop'), 7);
    });

    test('a save it made after this game started from scratch wins', () async {
      final (container, prefs) = await createContainer();
      final controller = container.read(gameControllerProvider.notifier)
        ..train();
      await prefs.setString(
        GameController.saveKey,
        saveOf(const GameState(generators: {'laptop': 3}), now),
      );
      controller.tick(10);
      await pumpEventQueue();
      expect(container.read(gameControllerProvider).state.owned('laptop'), 3);
    });

    test('resuming adopts its save instead of crediting the gap', () async {
      final (container, prefs) = await createContainer(
        preferences: {
          GameController.saveKey: saveOf(
            const GameState(generators: {'laptop': 2}),
            now.subtract(const Duration(minutes: 30)),
          ),
        },
      );
      final controller = container.read(gameControllerProvider.notifier)
        ..dismissOffline();
      await prefs.setString(
        GameController.saveKey,
        saveOf(const GameState(tokens: 42), now),
      );
      await controller.resumeAfter(const Duration(minutes: 5));
      final session = container.read(gameControllerProvider);
      expect(session.state.tokens, 42);
      expect(session.offline, isNull);
    });

    test('our own saves are not mistaken for its saves', () async {
      var clock = now;
      final (container, _) = await createContainer(clock: () => clock);
      final controller = container.read(gameControllerProvider.notifier)
        ..train();
      clock = now.add(const Duration(seconds: 10));
      controller.tick(10);
      await pumpEventQueue();
      clock = now.add(const Duration(seconds: 20));
      controller
        ..train()
        ..tick(10);
      await pumpEventQueue();
      expect(container.read(gameControllerProvider).state.manualTrainings, 2);
    });
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
    await tester.pump();
    final session = container.read(gameControllerProvider);
    expect(session.offline?.credited, const Duration(minutes: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with reduced motion the game loop runs without frames', (
    tester,
  ) async {
    var clock = now;
    SharedPreferences.setMockInitialValues({
      GameController.saveKey: saveOf(
        const GameState(generators: {'laptop': 2}),
        now,
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GameLoop(child: SizedBox()),
        ),
      ),
    );
    final before = container.read(gameControllerProvider).state.tokens;
    for (var i = 0; i < 10; i++) {
      clock = clock.add(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    final after = container.read(gameControllerProvider).state.tokens;
    expect(after - before, closeTo(1, 1e-6));

    clock = clock.add(const Duration(minutes: 30));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(
      container.read(gameControllerProvider).offline?.credited,
      const Duration(minutes: 30),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the game loop credits a sleep the frame clock missed', (
    tester,
  ) async {
    var clock = now;
    SharedPreferences.setMockInitialValues({
      GameController.saveKey: saveOf(
        const GameState(generators: {'laptop': 2}),
        now,
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GameLoop(child: SizedBox()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      clock = clock.add(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(container.read(gameControllerProvider).offline, isNull);

    // The device slept for half an hour: frame time barely moved.
    clock = clock.add(const Duration(minutes: 30));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    final session = container.read(gameControllerProvider);
    expect(session.offline?.credited, const Duration(minutes: 30));
    await tester.pumpWidget(const SizedBox());
  });
}
