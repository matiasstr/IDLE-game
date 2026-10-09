// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Neural Idle';

  @override
  String get tokens => 'Tokens';

  @override
  String get tokensPerSecond => 'Tokens / sec';

  @override
  String get accuracy => 'Accuracy';

  @override
  String get loss => 'Loss';

  @override
  String get architecture => 'Architecture';

  @override
  String stageLabel(int stage, int total) {
    return 'Stage $stage / $total';
  }

  @override
  String get nextArchitecture => 'Next architecture';

  @override
  String get train => 'Train model';

  @override
  String get buy => 'Buy';

  @override
  String get owned => 'Owned';

  @override
  String get locked => 'Locked';

  @override
  String get purchased => 'Purchased';

  @override
  String get hardware => 'Hardware';

  @override
  String get research => 'Research';

  @override
  String get stats => 'Stats';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'Use device language';

  @override
  String get offlineTitle => 'Welcome back, trainer';

  @override
  String offlineBody(String duration, String tokens) {
    return 'While you were away for $duration, your AI trained and earned $tokens tokens.';
  }

  @override
  String get collect => 'Collect tokens';

  @override
  String get trainingLab => 'TRAINING LAB';

  @override
  String get modelStatus => 'Model status';

  @override
  String get modelVoice => 'MODEL OUTPUT';

  @override
  String get resourceOverview => 'Resources';

  @override
  String get trainingHint => 'Every token brings your model closer.';

  @override
  String get debugOffline => 'Preview offline progress';

  @override
  String get close => 'Close';

  @override
  String progressLabel(String progress) {
    return '$progress% to next architecture';
  }
}
