import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neural_idle/app/app.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle/state/game_controller.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'the network keeps its state when the layout starts or stops scrolling',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const NeuralIdleApp(),
        ),
      );
      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pump(const Duration(milliseconds: 300));

      State network() => tester.state(find.byType(NeuralNetworkView));
      State chart() => tester.state(find.byType(LossChart));
      final firstNetwork = network(), firstChart = chart();

      // A short desktop window makes the training column scroll (< 440 px).
      await pumpAt(tester, const Size(1440, 500));
      expect(identical(network(), firstNetwork), isTrue);
      expect(identical(chart(), firstChart), isTrue);

      await pumpAt(tester, const Size(1440, 900));
      expect(identical(network(), firstNetwork), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a report that arrives while the offline dialog is open is '
      'shown after it, not dropped', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      GameController.saveKey: const SaveCodec().encode(
        const GameState(generators: {'laptop': 10}),
        savedAt: DateTime.now().subtract(const Duration(hours: 3)),
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
        child: const NeuralIdleApp(),
      ),
    );
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OfflineProgressDialog), findsOneWidget);

    // The tab is hidden again (or the device sleeps) with the dialog open.
    final controller = container.read(gameControllerProvider.notifier);
    final first = container.read(gameControllerProvider).offline;
    unawaited(controller.resumeAfter(const Duration(hours: 2)));
    await tester.pump();
    final second = container.read(gameControllerProvider).offline;
    expect(identical(second, first), isFalse);

    await tester.tap(find.text('Collect tokens'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OfflineProgressDialog), findsOneWidget);
    expect(
      identical(container.read(gameControllerProvider).offline, second),
      isTrue,
    );

    await tester.tap(find.text('Collect tokens'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OfflineProgressDialog), findsNothing);
    expect(container.read(gameControllerProvider).offline, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
