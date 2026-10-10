import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/ui/widgets/coach_mark.dart';

import 'widget_test_helpers.dart';

Widget anchoredTarget({
  required GlobalKey target,
  required bool bottom,
  required VoidCallback onDismiss,
  required ValueChanged<VoidCallback> onOpen,
}) => Builder(
  builder: (context) => Stack(
    children: [
      Positioned(
        left: bottom ? null : 8,
        right: bottom ? 8 : null,
        top: bottom ? null : 8,
        bottom: bottom ? 8 : null,
        child: SizedBox(
          key: target,
          width: 48,
          height: 48,
          child: FilledButton(
            onPressed: () => onOpen(
              showCoachMark(
                context,
                target: target,
                message: AppLocalizations.of(context).hintTrain,
                onDismiss: onDismiss,
              ),
            ),
            child: const Text('?'),
          ),
        ),
      ),
    ],
  ),
);

void main() {
  for (final size in [const Size(360, 640), const Size(1440, 900)]) {
    for (final bottom in [false, true]) {
      final edge = bottom ? 'bottom' : 'top';
      testWidgets('hint fits $size at $edge', (tester) async {
        final target = GlobalKey();
        VoidCallback? close;
        var dismissals = 0;
        await pumpSubject(
          tester,
          anchoredTarget(
            target: target,
            bottom: bottom,
            onDismiss: () => dismissals++,
            onOpen: (callback) => close = callback,
          ),
          size: size,
        );
        await tester.tap(find.text('?'));
        await finishTransition(tester);
        final rect = tester.getRect(
          find.byKey(const ValueKey('coach-mark-overlay')),
        );
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.top, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(size.width - 12));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 12));
        expect(
          tester.widget<CoachMark>(find.byType(CoachMark)).pointing,
          bottom ? AxisDirection.down : AxisDirection.up,
        );
        await tester.tap(find.byType(CoachMark));
        await tester.pump();
        expect(find.byType(CoachMark), findsNothing);
        expect(dismissals, 1);
        close!();
        close!();
        await tester.pump();
        expect(dismissals, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Spanish hint is announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpSubject(
        tester,
        anchoredTarget(
          target: GlobalKey(),
          bottom: false,
          onDismiss: () {},
          onOpen: (_) {},
        ),
        locale: const Locale('es'),
      );
      await tester.tap(find.text('?'));
      await finishTransition(tester);
      expect(
        find.text('Tocá Entrenar modelo para ganar tus primeros tokens'),
        findsOneWidget,
      );
      final node = tester.getSemantics(find.byType(CoachMark));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      await tester.tap(find.byType(CoachMark));
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduced motion shows the hint without a fade', (tester) async {
    var visible = false;
    await pumpSubject(
      tester,
      StatefulBuilder(
        builder: (context, setState) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Column(
            children: [
              TextButton(
                onPressed: () => setState(() => visible = true),
                child: const Text('show'),
              ),
              if (visible)
                CoachMark(message: 'Immediate hint', onDismiss: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    final fade = find.descendant(
      of: find.byType(CoachMark),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(fade).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teardown releases the entry and repeated close is safe', (
    tester,
  ) async {
    VoidCallback? close;
    var dismissals = 0;
    await pumpSubject(
      tester,
      anchoredTarget(
        target: GlobalKey(),
        bottom: false,
        onDismiss: () => dismissals++,
        onOpen: (callback) => close = callback,
      ),
    );
    await tester.tap(find.text('?'));
    await finishTransition(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    close!();
    expect(dismissals, 0);
    expect(find.byType(CoachMark), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing target creates no entry', (tester) async {
    var dismissals = 0;
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCoachMark(
            context,
            target: GlobalKey(),
            message: 'Unavailable target',
            onDismiss: () => dismissals++,
          )(),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byType(CoachMark), findsNothing);
    expect(dismissals, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route pop removes the coach mark', (tester) async {
    final target = GlobalKey();
    VoidCallback? close;
    var dismissals = 0;
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: anchoredTarget(
                  target: target,
                  bottom: false,
                  onDismiss: () => dismissals++,
                  onOpen: (callback) => close = callback,
                ),
              ),
            ),
          ),
          child: const Text('route'),
        ),
      ),
    );
    await tester.tap(find.text('route'));
    await finishTransition(tester);
    await tester.tap(find.text('?'));
    await finishTransition(tester);
    Navigator.of(target.currentContext!).pop();
    await finishTransition(tester);
    expect(find.byType(CoachMark), findsNothing);
    close!();
    expect(dismissals, 0);
    expect(tester.takeException(), isNull);
  });

  test('onboarding placeholders keep formatted values and names', () {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(
      es.hintBuyHardware('Old Laptop'),
      'El hardware entrena por vos: comprá Old Laptop',
    );
    expect(
      es.hintEvolve('12.4K', 'CNN'),
      'Ganá 12.4K tokens en esta partida y tu red evoluciona a CNN',
    );
    expect(es.hintResearch, contains('Investigación'));
  });
}
