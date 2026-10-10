import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/dev/widget_preview.dart';

import 'widget_test_helpers.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final locale in [const Locale('en'), const Locale('es')]) {
      testWidgets('preview fits $size in ${locale.languageCode}', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const WidgetPreview(),
          size: size,
          locale: locale,
        );
        await tester.tap(find.text('×10').first);
        await tester.pump();
        expect(find.text('254 · ×10'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final list = find.byType(ListView).first;
        for (var i = 0; i < 7; i++) {
          await tester.drag(list, const Offset(0, -300));
          await finishTransition(tester);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
