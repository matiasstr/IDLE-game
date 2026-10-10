import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/widgets/publish_paper_card.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('paper card delegates publishing and explains permanent bonus', (
    tester,
  ) async {
    bool? result;
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => PublishPaperCard(
          citationsGain: '42',
          currentCitations: '128',
          bonusAfter: '×1.85',
          enabled: true,
          onPublish: () async {
            result = await showPublishPaperDialog(
              context,
              citationsGain: '42',
              bonusAfter: '×1.85',
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Publish paper').last);
    await finishTransition(tester);
    expect(find.textContaining('permanent bonus'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await finishTransition(tester);
    expect(result, isFalse);
    await tester.tap(find.text('Publish paper').last);
    await finishTransition(tester);
    await tester.tap(find.text('Publish and restart'));
    await finishTransition(tester);
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null callbacks and locked paper cards cannot publish', (
    tester,
  ) async {
    await pumpSubject(
      tester,
      const PublishPaperCard(
        citationsGain: '0',
        currentCitations: '0',
        bonusAfter: '×1.00',
        enabled: false,
      ),
    );
    expect(find.textContaining('Reach the Transformer'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    await pumpSubject(
      tester,
      const PublishPaperCard(
        citationsGain: '42',
        currentCitations: '128',
        bonusAfter: '×1.85',
        enabled: true,
      ),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('dismissing the confirmation returns false', (tester) async {
    bool? result;
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showPublishPaperDialog(
              context,
              citationsGain: '42',
              bonusAfter: '×1.85',
            );
          },
          child: const Text('confirm'),
        ),
      ),
    );
    await tester.tap(find.text('confirm'));
    await finishTransition(tester);
    await tester.tapAt(const Offset(5, 5));
    await finishTransition(tester);
    expect(result, isFalse);
  });
}
