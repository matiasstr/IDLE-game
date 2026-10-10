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
    return 'While you were away, your AI trained for $duration and earned $tokens tokens.';
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

  @override
  String ratePerSecond(String value) {
    return '+$value/s';
  }

  @override
  String buyQuantity(String count) {
    return 'Buy ×$count';
  }

  @override
  String get buyMax => 'Buy max';

  @override
  String get evolvedTitle => 'New architecture unlocked';

  @override
  String offlineEvolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your model evolved $count times while you were away',
      one: 'Your model evolved once while you were away',
      zero: 'Your model did not evolve while you were away',
    );
    return '$_temp0';
  }

  @override
  String get statsLifetimeTokens => 'Lifetime tokens';

  @override
  String get statsPlayTime => 'Play time';

  @override
  String get statsManualTrainings => 'Manual trainings';

  @override
  String get statsPapers => 'Published papers';

  @override
  String get statsCitations => 'Citations';

  @override
  String get statsCitationBonus => 'Citation bonus';

  @override
  String get publishPaper => 'Publish paper';

  @override
  String get publishPaperBody =>
      'Publishing a paper resets your training progress. Your citations stay and give all future training a permanent bonus.';

  @override
  String get publishConfirm => 'Publish and restart';

  @override
  String get cancel => 'Cancel';

  @override
  String citationsGain(String count) {
    return '+$count citations';
  }

  @override
  String get publishLocked =>
      'Reach the Transformer to publish your first paper';

  @override
  String get resetProgress => 'Reset progress';

  @override
  String get resetProgressConfirm =>
      'Delete all training progress, papers, and citations? This cannot be undone.';

  @override
  String get exportSave => 'Export save';

  @override
  String get importSave => 'Import save';

  @override
  String get importInvalid =>
      'This save could not be imported. Check the text and try again.';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get about => 'About';

  @override
  String get sourceCode => 'Source code';

  @override
  String get builtWithFlutter => 'Built with Flutter';

  @override
  String networkSemanticLabel(String architecture) {
    return 'Neural network: $architecture';
  }

  @override
  String get trainSemanticHint => 'Train the model once';

  @override
  String get buyAmount => 'Purchase amount';

  @override
  String researchAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count affordable upgrades',
      one: '1 affordable upgrade',
    );
    return '$_temp0';
  }

  @override
  String get currentCitations => 'Current citations';

  @override
  String get bonusAfter => 'Bonus after publishing';

  @override
  String get saveData => 'Save data';

  @override
  String get importSaveHint => 'Paste an exported save';

  @override
  String get importSaveBody => 'Importing replaces your current game progress.';

  @override
  String get exportFailed => 'The save could not be exported. Try again.';

  @override
  String get copyFailed =>
      'Could not copy. Select the text to copy it manually.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get widgetPreview => 'Widget preview';

  @override
  String get previewTitle => 'Component preview';

  @override
  String get previewDescription =>
      'Demo data. These controls do not change your game.';

  @override
  String get previewEvolution => 'Preview evolution';

  @override
  String get hintTrain => 'Tap Train model to earn your first tokens';

  @override
  String hintBuyHardware(String name) {
    return 'Hardware trains for you: buy $name';
  }

  @override
  String hintEvolve(String tokens, String architecture) {
    return 'Earn $tokens tokens this run and your network evolves into $architecture';
  }

  @override
  String get hintResearch =>
      'Research multiplies everything. Check the Research tab';

  @override
  String publishLockedNext(String architecture) {
    return 'Reach the $architecture again to publish your next paper';
  }

  @override
  String get buyMaxShort => 'MAX';
}
