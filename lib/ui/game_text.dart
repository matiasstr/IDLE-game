import 'package:flutter/widgets.dart';
import 'package:neural_idle_core/neural_idle_core.dart';

/// Formats engine values for display in the current language.
@immutable
class GameText {
  const GameText(this.languageCode);

  factory GameText.of(BuildContext context) =>
      GameText(Localizations.localeOf(context).languageCode);

  final String languageCode;

  String amount(double value) =>
      formatAmount(value, languageCode: languageCode);

  /// "+1.23K/s".
  String rate(double perSecond) => '+${amount(perSecond)}/s';

  /// "+12".
  String gain(double value) => '+${amount(value)}';

  String percent(double ratio) =>
      formatPercent(ratio, languageCode: languageCode);

  String get decimalSeparator => languageCode == 'es' ? ',' : '.';

  /// "2.30" above 1, otherwise three significant digits ("0.0421").
  String loss(double value) {
    final text = value >= 1
        ? value.toStringAsFixed(2)
        : value.toStringAsPrecision(3);
    return text.replaceAll('.', decimalSeparator);
  }

  String duration(Duration value) => formatDuration(value);

  String of(LocalizedText text) => text.resolve(languageCode);
}
