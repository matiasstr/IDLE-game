import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/generator_card.dart';

import 'widget_test_helpers.dart';

GeneratorCard card({String? quantity, VoidCallback? onBuy}) => GeneratorCard(
  icon: Icons.memory,
  name: 'GPU',
  description: 'Training hardware',
  owned: 6,
  cost: '2.54K',
  production: '+40/s',
  canAfford: true,
  quantityLabel: quantity,
  onBuy: onBuy,
);

void main() {
  testWidgets('quantity accompanies cost and delegates purchase', (
    tester,
  ) async {
    var purchases = 0;
    await pumpSubject(tester, card(quantity: '×10', onBuy: () => purchases++));
    expect(find.text('2.54K · ×10'), findsOneWidget);
    await tester.tap(find.text('Buy'));
    expect(purchases, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing usage omits quantity and null callback disables purchase',
    (tester) async {
      await pumpSubject(tester, card());
      expect(find.text('2.54K'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
}
