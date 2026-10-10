import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Neural Idle'**
  String get appTitle;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get tokens;

  /// No description provided for @tokensPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Tokens / sec'**
  String get tokensPerSecond;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @loss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get loss;

  /// No description provided for @architecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get architecture;

  /// No description provided for @stageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} / {total}'**
  String stageLabel(int stage, int total);

  /// No description provided for @nextArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Next architecture'**
  String get nextArchitecture;

  /// No description provided for @train.
  ///
  /// In en, this message translates to:
  /// **'Train model'**
  String get train;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @purchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get purchased;

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @research.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get research;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get systemLanguage;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, trainer'**
  String get offlineTitle;

  /// No description provided for @offlineBody.
  ///
  /// In en, this message translates to:
  /// **'While you were away, your AI trained for {duration} and earned {tokens} tokens.'**
  String offlineBody(String duration, String tokens);

  /// No description provided for @collect.
  ///
  /// In en, this message translates to:
  /// **'Collect tokens'**
  String get collect;

  /// No description provided for @trainingLab.
  ///
  /// In en, this message translates to:
  /// **'TRAINING LAB'**
  String get trainingLab;

  /// No description provided for @modelStatus.
  ///
  /// In en, this message translates to:
  /// **'Model status'**
  String get modelStatus;

  /// No description provided for @modelVoice.
  ///
  /// In en, this message translates to:
  /// **'MODEL OUTPUT'**
  String get modelVoice;

  /// No description provided for @resourceOverview.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resourceOverview;

  /// No description provided for @trainingHint.
  ///
  /// In en, this message translates to:
  /// **'Every token brings your model closer.'**
  String get trainingHint;

  /// No description provided for @debugOffline.
  ///
  /// In en, this message translates to:
  /// **'Preview offline progress'**
  String get debugOffline;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'{progress}% to next architecture'**
  String progressLabel(String progress);

  /// No description provided for @ratePerSecond.
  ///
  /// In en, this message translates to:
  /// **'+{value}/s'**
  String ratePerSecond(String value);

  /// No description provided for @buyQuantity.
  ///
  /// In en, this message translates to:
  /// **'Buy ×{count}'**
  String buyQuantity(String count);

  /// No description provided for @buyMax.
  ///
  /// In en, this message translates to:
  /// **'Buy max'**
  String get buyMax;

  /// No description provided for @evolvedTitle.
  ///
  /// In en, this message translates to:
  /// **'New architecture unlocked'**
  String get evolvedTitle;

  /// No description provided for @offlineEvolved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Your model did not evolve while you were away} one{Your model evolved once while you were away} other{Your model evolved {count} times while you were away}}'**
  String offlineEvolved(int count);

  /// No description provided for @statsLifetimeTokens.
  ///
  /// In en, this message translates to:
  /// **'Lifetime tokens'**
  String get statsLifetimeTokens;

  /// No description provided for @statsPlayTime.
  ///
  /// In en, this message translates to:
  /// **'Play time'**
  String get statsPlayTime;

  /// No description provided for @statsManualTrainings.
  ///
  /// In en, this message translates to:
  /// **'Manual trainings'**
  String get statsManualTrainings;

  /// No description provided for @statsPapers.
  ///
  /// In en, this message translates to:
  /// **'Published papers'**
  String get statsPapers;

  /// No description provided for @statsCitations.
  ///
  /// In en, this message translates to:
  /// **'Citations'**
  String get statsCitations;

  /// No description provided for @statsCitationBonus.
  ///
  /// In en, this message translates to:
  /// **'Citation bonus'**
  String get statsCitationBonus;

  /// No description provided for @publishPaper.
  ///
  /// In en, this message translates to:
  /// **'Publish paper'**
  String get publishPaper;

  /// No description provided for @publishPaperBody.
  ///
  /// In en, this message translates to:
  /// **'Publishing a paper resets your training progress. Your citations stay and give all future training a permanent bonus.'**
  String get publishPaperBody;

  /// No description provided for @publishConfirm.
  ///
  /// In en, this message translates to:
  /// **'Publish and restart'**
  String get publishConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @citationsGain.
  ///
  /// In en, this message translates to:
  /// **'+{count} citations'**
  String citationsGain(String count);

  /// No description provided for @publishLocked.
  ///
  /// In en, this message translates to:
  /// **'Reach the Transformer to publish your first paper'**
  String get publishLocked;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get resetProgress;

  /// No description provided for @resetProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all training progress, papers, and citations? This cannot be undone.'**
  String get resetProgressConfirm;

  /// No description provided for @exportSave.
  ///
  /// In en, this message translates to:
  /// **'Export save'**
  String get exportSave;

  /// No description provided for @importSave.
  ///
  /// In en, this message translates to:
  /// **'Import save'**
  String get importSave;

  /// No description provided for @importInvalid.
  ///
  /// In en, this message translates to:
  /// **'This save could not be imported. Check the text and try again.'**
  String get importInvalid;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @builtWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter'**
  String get builtWithFlutter;

  /// No description provided for @networkSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Neural network: {architecture}'**
  String networkSemanticLabel(String architecture);

  /// No description provided for @trainSemanticHint.
  ///
  /// In en, this message translates to:
  /// **'Train the model once'**
  String get trainSemanticHint;

  /// No description provided for @buyAmount.
  ///
  /// In en, this message translates to:
  /// **'Purchase amount'**
  String get buyAmount;

  /// No description provided for @researchAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 affordable upgrade} other{{count} affordable upgrades}}'**
  String researchAvailable(int count);

  /// No description provided for @currentCitations.
  ///
  /// In en, this message translates to:
  /// **'Current citations'**
  String get currentCitations;

  /// No description provided for @bonusAfter.
  ///
  /// In en, this message translates to:
  /// **'Bonus after publishing'**
  String get bonusAfter;

  /// No description provided for @saveData.
  ///
  /// In en, this message translates to:
  /// **'Save data'**
  String get saveData;

  /// No description provided for @importSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an exported save'**
  String get importSaveHint;

  /// No description provided for @importSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Importing replaces your current game progress.'**
  String get importSaveBody;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The save could not be exported. Try again.'**
  String get exportFailed;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy. Select the text to copy it manually.'**
  String get copyFailed;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @widgetPreview.
  ///
  /// In en, this message translates to:
  /// **'Widget preview'**
  String get widgetPreview;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Component preview'**
  String get previewTitle;

  /// No description provided for @previewDescription.
  ///
  /// In en, this message translates to:
  /// **'Demo data. These controls do not change your game.'**
  String get previewDescription;

  /// No description provided for @previewEvolution.
  ///
  /// In en, this message translates to:
  /// **'Preview evolution'**
  String get previewEvolution;

  /// No description provided for @hintTrain.
  ///
  /// In en, this message translates to:
  /// **'Tap Train model to earn your first tokens'**
  String get hintTrain;

  /// No description provided for @hintBuyHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware trains for you: buy {name}'**
  String hintBuyHardware(String name);

  /// No description provided for @hintEvolve.
  ///
  /// In en, this message translates to:
  /// **'Earn {tokens} tokens this run and your network evolves into {architecture}'**
  String hintEvolve(String tokens, String architecture);

  /// No description provided for @hintResearch.
  ///
  /// In en, this message translates to:
  /// **'Research multiplies everything. Check the Research tab'**
  String get hintResearch;

  /// No description provided for @publishLockedNext.
  ///
  /// In en, this message translates to:
  /// **'Reach the {architecture} again to publish your next paper'**
  String publishLockedNext(String architecture);

  /// Short label of the buy-max segment
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get buyMaxShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
