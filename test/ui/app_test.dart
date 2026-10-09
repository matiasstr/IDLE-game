import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neural_idle/app/app.dart';
import 'package:neural_idle/app/locale_controller.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle/ui/layout/narrow_layout.dart';
import 'package:neural_idle/ui/layout/wide_layout.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> pumpApp(
  WidgetTester tester,
  Size size, {
  Map<String, Object> preferences = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localeTestValue = const Locale('en');
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NeuralIdleApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts();
  });
  await tester.pump(const Duration(milliseconds: 1200));
  return prefs;
}

void main() {
  testWidgets('starts with the training UI and all three wide columns', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1440, 900));
    expect(find.text('Neural Idle'), findsOneWidget);
    expect(find.text('Train model'), findsOneWidget);
    expect(find.byType(WideLayout), findsOneWidget);
    for (final column in [
      'wide-resources-column',
      'wide-training-column',
      'wide-store-column',
    ]) {
      expect(find.byKey(ValueKey(column)), findsOneWidget);
    }
    expect(find.text('NEURAL NET VIZ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish selection changes visible UI and persists', (
    tester,
  ) async {
    final prefs = await pumpApp(tester, const Size(1440, 900));
    await tester.tap(find.text('ES'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Entrenar modelo'), findsOneWidget);
    expect(find.text('Investigación'), findsOneWidget);
    expect(prefs.getString(LocaleController.preferenceKey), 'es');
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const NeuralIdleApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Entrenar modelo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(899, 900),
    const Size(390, 420),
  ]) {
    testWidgets('narrow tabs fit ${size.width} x ${size.height}', (
      tester,
    ) async {
      await pumpApp(tester, size);
      expect(find.byType(NarrowLayout), findsOneWidget);
      expect(find.byType(WideLayout), findsNothing);
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.height >= 560) {
        await tester.tap(find.text('Stats'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Research'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('wide layout starts at exactly 900 logical pixels', (
    tester,
  ) async {
    await pumpApp(tester, const Size(900, 900));
    expect(find.byType(WideLayout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile settings switches language and restores device selection',
    (tester) async {
      final prefs = await pumpApp(tester, const Size(360, 640));
      await tester.tap(find.byKey(const ValueKey('settings-button')));
      // Start the sheet transition before advancing its animation clock.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ES').hitTestable(), findsOneWidget);
      await tester.tap(find.text('ES'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Entrenar modelo'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump(const Duration(milliseconds: 300));
      expect(prefs.containsKey(LocaleController.preferenceKey), isFalse);
      expect(find.text('Train model'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid training taps create independent floating gains', (
    tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));
    final button = find.byKey(const ValueKey('train-button'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 40));
    }
    final gains = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('training-gain-'),
    );
    expect(gains, findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 800));
    expect(gains, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('debug offline dialog opens and collects', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('debug-offline')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OfflineProgressDialog), findsOneWidget);
    await tester.tap(find.text('Collect tokens'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OfflineProgressDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
