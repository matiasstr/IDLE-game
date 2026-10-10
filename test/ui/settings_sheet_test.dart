import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/ui/dev/widget_preview.dart';
import 'package:neural_idle/ui/widgets/settings_sheet.dart';

import 'widget_test_helpers.dart';

Future<void> tapAction(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await finishTransition(tester);
}

void main() {
  testWidgets('optional actions stay hidden without their callbacks', (
    tester,
  ) async {
    await pumpSubject(tester, const SettingsSheet());
    for (final label in [
      'Reset progress',
      'Export save',
      'Import save',
      'About',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('Widget preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset needs explicit confirmation before calling callback', (
    tester,
  ) async {
    var resets = 0;
    await pumpSubject(tester, SettingsSheet(onResetProgress: () => resets++));
    await tapAction(tester, 'Reset progress');
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tapAction(tester, 'Cancel');
    expect(resets, 0);
    await tapAction(tester, 'Reset progress');
    await tapAction(tester, 'Reset progress');
    expect(resets, 1);
  });

  testWidgets('export shows selectable data and copies the exact save', (
    tester,
  ) async {
    const raw = '{"version":1,"tokens":42}';
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpSubject(tester, SettingsSheet(exportSave: () => raw));
    await tapAction(tester, 'Export save');
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == raw,
      ),
      findsOneWidget,
    );
    await tapAction(tester, 'Copy');
    expect(clipboard, raw);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets(
    'invalid import stays open and a corrected save can be submitted',
    (tester) async {
      final submissions = <String>[];
      await pumpSubject(
        tester,
        SettingsSheet(
          importSave: (raw) {
            submissions.add(raw);
            return raw == 'valid-save';
          },
        ),
      );
      await tapAction(tester, 'Import save');
      await tester.enterText(find.byType(TextField), 'broken-save');
      await tapAction(tester, 'Import save');
      expect(find.textContaining('could not be imported'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'valid-save');
      await tester.pump();
      expect(find.textContaining('could not be imported'), findsNothing);
      await tapAction(tester, 'Import save');
      expect(submissions, ['broken-save', 'valid-save']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('import exceptions are shown as invalid data', (tester) async {
    await pumpSubject(
      tester,
      SettingsSheet(importSave: (_) => throw const FormatException()),
    );
    await tapAction(tester, 'Import save');
    await tapAction(tester, 'Import save');
    expect(find.textContaining('could not be imported'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet helper forwards save callbacks and version', (
    tester,
  ) async {
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSettingsSheet(
            context,
            onResetProgress: () {},
            exportSave: () => 'sample-save',
            importSave: (_) => true,
            version: '1.2.3',
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tapAction(tester, 'open');
    expect(find.text('Version 1.2.3'), findsOneWidget);
    expect(find.text('Built with Flutter'), findsOneWidget);
    expect(find.text('https://github.com/matiasstr/IDLE-game'), findsOneWidget);
    await tapAction(tester, 'Export save');
    expect(find.text('sample-save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debug settings opens the component preview', (tester) async {
    await pumpSubject(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSettingsSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tapAction(tester, 'open');
    await tapAction(tester, 'Widget preview');
    expect(find.byType(WidgetPreview), findsOneWidget);
    expect(find.text('Component preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
