import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neural_idle/app/app.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle/state/game_controller.dart';
import 'package:neural_idle/state/onboarding.dart';
import 'package:neural_idle/ui/widgets/coach_mark.dart';
import 'package:neural_idle/ui/widgets/evolution_banner.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole app with a fresh preferences store. Returns the container to
/// look at the game, and the preferences.
Future<(ProviderContainer, SharedPreferences)> pumpGame(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  GameState? game,
  DateTime? savedAt,
  // Hints off unless a test is about them.
  Set<OnboardingStep> dismissed = const {
    OnboardingStep.train,
    OnboardingStep.buyHardware,
    OnboardingStep.evolve,
    OnboardingStep.research,
  },
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localeTestValue = const Locale('en');
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  SharedPreferences.setMockInitialValues({
    if (game != null)
      GameController.saveKey: const SaveCodec().encode(
        game,
        savedAt: savedAt ?? DateTime.now(),
      ),
    OnboardingController.key: [for (final step in dismissed) step.name],
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NeuralIdleApp(),
    ),
  );
  await tester.runAsync(GoogleFonts.pendingFonts);
  await settle(tester);
  return (container, prefs);
}

/// Lets the UI catch up: the game loop and animations never stop, so
/// pumpAndSettle would time out.
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GameState stateOf(ProviderContainer container) =>
    container.read(gameControllerProvider).state;

void main() {
  group('first-run hints', () {
    testWidgets('a new player is told to train, and the hint leaves once '
        'they do', (tester) async {
      await pumpGame(tester, dismissed: const {});
      expect(find.byType(CoachMark), findsOneWidget);
      expect(
        find.text('Tap Train model to earn your first tokens'),
        findsOneWidget,
      );
      // It points at the train button: right above or below it.
      final hint = tester.getRect(find.byType(CoachMark));
      final button = tester.getRect(find.byKey(const ValueKey('train-button')));
      expect(
        (hint.bottom - button.top).abs() < 40 ||
            (hint.top - button.bottom).abs() < 40,
        isTrue,
        reason: 'hint $hint, button $button',
      );

      await tester.tap(find.byKey(const ValueKey('train-button')));
      await settle(tester);
      expect(find.byType(CoachMark), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tapping a hint dismisses it for good', (tester) async {
      final (container, prefs) = await pumpGame(tester, dismissed: const {});
      await tester.tap(find.byType(CoachMark));
      await settle(tester);
      expect(find.byType(CoachMark), findsNothing);
      expect(container.read(onboardingProvider), {OnboardingStep.train});
      expect(prefs.getStringList(OnboardingController.key), ['train']);
      expect(stateOf(container).manualTrainings, 0, reason: 'not a training');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the next hint points at the first hardware', (tester) async {
      await pumpGame(
        tester,
        dismissed: const {},
        game: const GameState(
          tokens: 12,
          runTokens: 12,
          lifetimeTokens: 12,
          manualTrainings: 12,
        ),
      );
      expect(find.byType(CoachMark), findsOneWidget);
      expect(
        find.textContaining('Hardware trains for you: buy'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no hints over the offline report', (tester) async {
      await pumpGame(
        tester,
        dismissed: const {},
        game: const GameState(generators: {'laptop': 2}),
        savedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(find.byType(OfflineProgressDialog), findsOneWidget);
      expect(find.byType(CoachMark), findsNothing);
      await tester.tap(find.text('Collect tokens'));
      await settle(tester);
      // Hardware is running and the MLP is still ahead.
      expect(find.byType(CoachMark), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('×10 and MAX buy several units at once', (tester) async {
    final (container, _) = await pumpGame(
      tester,
      game: const GameState(tokens: 1000, runTokens: 50, lifetimeTokens: 50),
    );
    await tester.tap(find.text('×10'));
    await settle(tester, 2);
    expect(find.textContaining('· ×10'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('hardware-laptop')),
        matching: find.byType(FilledButton),
      ),
    );
    await settle(tester, 2);
    expect(stateOf(container).owned('laptop'), 10);

    await tester.tap(find.text('MAX'));
    await settle(tester, 2);
    final engine = container.read(gameEngineProvider);
    final max = engine.maxAffordable(stateOf(container), 'laptop');
    expect(max, greaterThan(0));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('hardware-laptop')),
        matching: find.byType(FilledButton),
      ),
    );
    await settle(tester, 2);
    expect(stateOf(container).owned('laptop'), 10 + max);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('buy buttons tell screen readers what they buy', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, game: const GameState(tokens: 50));
    expect(
      find.bySemanticsLabel(RegExp(r'^Buy Old Laptop, \d')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('the Stats tab shows lifetime numbers and publishes papers', (
    tester,
  ) async {
    final (container, _) = await pumpGame(
      tester,
      game: const GameState(
        runTokens: 4e8,
        lifetimeTokens: 5e8,
        manualTrainings: 321,
        playSeconds: 3700,
      ),
    );
    await tester.tap(find.text('Stats'));
    await settle(tester, 8);
    expect(find.text('Lifetime tokens'), findsOneWidget);
    expect(find.text('1h 1m'), findsOneWidget);
    expect(find.text('321'), findsOneWidget);

    final engine = container.read(gameEngineProvider);
    final gain = engine.citationsForPublishing(stateOf(container));
    expect(gain, greaterThan(0));
    await tester.tap(find.widgetWithText(FilledButton, 'Publish paper'));
    await settle(tester, 4);
    // Confirmation first: nothing happens on cancel.
    await tester.tap(find.text('Cancel'));
    await settle(tester, 4);
    expect(stateOf(container).papersPublished, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Publish paper'));
    await settle(tester, 4);
    await tester.tap(find.text('Publish and restart'));
    await settle(tester, 4);
    final after = stateOf(container);
    expect(after.papersPublished, 1);
    expect(after.citations, gain);
    expect(after.runTokens, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings reset the game after confirming', (tester) async {
    final (container, _) = await pumpGame(
      tester,
      game: const GameState(tokens: 77, manualTrainings: 5),
    );
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await settle(tester, 6);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset progress'));
    await tester.tap(find.text('Reset progress'));
    await settle(tester, 4);
    // The confirmation's destructive button.
    await tester.tap(find.widgetWithText(FilledButton, 'Reset progress'));
    await settle(tester, 6);
    // A new game (the loop has been running for a moment since).
    final reset = stateOf(container);
    expect(reset.tokens, 0);
    expect(reset.manualTrainings, 0);
    expect(reset.lifetimeTokens, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an evolution is announced at the peak of its animation', (
    tester,
  ) async {
    final (container, _) = await pumpGame(
      tester,
      game: const GameState(
        tokens: 299,
        runTokens: 299,
        lifetimeTokens: 299,
        manualTrainings: 299,
      ),
    );
    expect(find.byType(EvolutionBanner), findsNothing);
    container.read(gameControllerProvider.notifier).train();
    await settle(tester, 25);
    expect(find.byType(EvolutionBanner), findsOneWidget);
    expect(find.text('New architecture unlocked'), findsOneWidget);
    expect(find.text('MLP'), findsWidgets);
    // It leaves by itself.
    await settle(tester, 40);
    expect(find.byType(EvolutionBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the offline report counts evolutions while away', (
    tester,
  ) async {
    await pumpGame(
      tester,
      game: const GameState(generators: {'laptop': 40}),
      savedAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(find.byType(OfflineProgressDialog), findsOneWidget);
    expect(find.textContaining('Your model evolved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
