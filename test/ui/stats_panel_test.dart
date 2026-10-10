import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/stats_panel.dart';

import 'widget_test_helpers.dart';

void main() {
  for (final width in [360.0, 1440.0]) {
    testWidgets('stats wrap long values without overflow at $width', (
      tester,
    ) async {
      await pumpSubject(
        tester,
        const StatsPanel(
          entries: [
            StatEntry(
              'Lifetime tokens earned through every training run',
              '123.456789Qa',
              icon: Icons.token_outlined,
            ),
            StatEntry('Citation bonus', '×1.64'),
          ],
        ),
        size: Size(width, 640),
      );
      expect(find.text('×1.64'), findsOneWidget);
      final value = tester.widget<Text>(find.text('123.456789Qa'));
      expect(value.style!.fontFamily, contains('JetBrainsMono'));
      expect(
        value.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
