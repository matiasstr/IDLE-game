import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/locale_controller.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_theme.dart';
import 'package:neural_idle/ui/screens/home_screen.dart';

class NeuralIdleApp extends ConsumerWidget {
  const NeuralIdleApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    theme: AppTheme.dark,
    locale: ref.watch(localeControllerProvider),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: (locale, supported) => supported.firstWhere(
      (candidate) => candidate.languageCode == locale?.languageCode,
      orElse: () => const Locale('en'),
    ),
    home: const HomeScreen(),
  );
}
