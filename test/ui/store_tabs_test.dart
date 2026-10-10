import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/store_tabs.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets(
    'zero hides badge and available research remains accessible at 360px',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await pumpSubject(
        tester,
        const StoreTabs(
          hardware: Text('hardware body'),
          research: Text('research body'),
        ),
      );
      expect(find.byKey(const ValueKey('research-badge')), findsNothing);
      await pumpSubject(
        tester,
        const StoreTabs(
          hardware: Text('hardware body'),
          research: Text('research body'),
          stats: Text('stats body'),
          researchBadge: 12,
        ),
        locale: const Locale('es'),
      );
      expect(find.text('12'), findsOneWidget);
      expect(
        find.bySemanticsLabel('12 mejoras disponibles para comprar'),
        findsOneWidget,
      );
      await tester.tap(find.text('Investigación'));
      await finishTransition(tester);
      expect(find.text('research body').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
