import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/evolution_banner.dart';

import 'widget_test_helpers.dart';

Widget trigger() => Builder(
  builder: (context) => TextButton(
    onPressed: () => showEvolutionBanner(
      context,
      architecture: 'CNN',
      description: 'Convolutional Neural Network',
      stage: 3,
      totalStages: 8,
    ),
    child: const Text('evolve'),
  ),
);

void main() {
  testWidgets('localized evolution overlay closes automatically', (
    tester,
  ) async {
    await pumpSubject(tester, trigger(), locale: const Locale('es'));
    await tester.tap(find.text('evolve'));
    await finishTransition(tester);
    expect(find.text('Nueva arquitectura desbloqueada'), findsOneWidget);
    expect(find.text('Etapa 3 / 8'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pump();
    expect(find.byType(EvolutionBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping evolution closes it and cancels its timer', (
    tester,
  ) async {
    await pumpSubject(tester, trigger());
    await tester.tap(find.text('evolve'));
    await finishTransition(tester);
    await tester.tap(find.text('CNN'));
    await tester.pump();
    expect(find.byType(EvolutionBanner), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay teardown cancels pending dismissal', (tester) async {
    await pumpSubject(tester, trigger());
    await tester.tap(find.text('evolve'));
    await finishTransition(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
