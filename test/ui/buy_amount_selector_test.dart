import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/buy_amount_selector.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('purchase amount changes through its controlled callback', (
    tester,
  ) async {
    var amount = BuyAmount.one;
    await pumpSubject(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BuyAmountSelector(
          value: amount,
          onChanged: (next) => setState(() => amount = next),
        ),
      ),
    );
    await tester.tap(find.text('×10'));
    await tester.pump();
    expect(amount, BuyAmount.ten);
    expect(
      tester
          .widget<SegmentedButton<BuyAmount>>(
            find.byType(SegmentedButton<BuyAmount>),
          )
          .selected,
      {BuyAmount.ten},
    );
    await tester.tap(find.text('MAX'));
    await tester.pump();
    expect(amount, BuyAmount.max);
    expect(tester.takeException(), isNull);
  });
}
