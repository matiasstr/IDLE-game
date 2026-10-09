import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/locale_controller.dart';
import 'package:neural_idle/l10n/app_localizations.dart';

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeControllerProvider) ?? Localizations.localeOf(context);
    return Semantics(
      label: AppLocalizations.of(context).language,
      child: SegmentedButton<String>(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
        ),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'en', label: Text('EN')),
          ButtonSegment(value: 'es', label: Text('ES')),
        ],
        selected: {locale.languageCode == 'es' ? 'es' : 'en'},
        onSelectionChanged: (values) => ref
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(values.single)),
      ),
    );
  }
}
