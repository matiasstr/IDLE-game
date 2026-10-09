import 'dart:math' as math;

const _suffixes = [
  'K',
  'M',
  'B',
  'T',
  'Qa',
  'Qi',
  'Sx',
  'Sp',
  'Oc',
  'No',
  'Dc'
];

/// Absorbs binary representation error before truncating
/// (e.g. `1.23 * 100 == 122.99999999999999`).
const _epsilon = 1e-9;

/// Formats a game quantity compactly: `0.5`, `12.3`, `999`, `1.23K`,
/// `45.6M`, `789B`… and `1.23e36` beyond the named suffixes.
///
/// Values are truncated, never rounded up, so the player never sees more
/// tokens than they have. Spanish uses a decimal comma (`1,23K`); the
/// short-scale suffixes common in games are used for both languages.
String formatAmount(double value, {String languageCode = 'en'}) {
  if (value.isNaN) return '-';
  if (value < 0) return '-${formatAmount(-value, languageCode: languageCode)}';
  if (value.isInfinite) return '∞';

  // Below 100 keep one decimal so fractional rates such as 0.5/s show up.
  final tenths = (value * 10 + _epsilon).floor();
  if (tenths < 1000) {
    final whole = tenths ~/ 10;
    final decimal = tenths % 10;
    return decimal == 0 ? '$whole' : _localize('$whole.$decimal', languageCode);
  }
  final units = (value + _epsilon).floor();
  if (units < 1000) return '$units';

  var exponent = _exponentOf(value);
  // The three significant digits, e.g. 123 for 1.23K, 12.3K or 123K.
  var digits = (value / math.pow(10.0, exponent - 2) + _epsilon).floor();
  if (digits >= 1000) {
    exponent += 1;
    digits = 100;
  }

  if (exponent >= 3 * (_suffixes.length + 1)) {
    final decimals = (digits % 100).toString().padLeft(2, '0');
    return _localize('${digits ~/ 100}.${decimals}e$exponent', languageCode);
  }
  final integerDigits = exponent % 3 + 1;
  final text = '$digits';
  final mantissa = integerDigits == 3
      ? text
      : '${text.substring(0, integerDigits)}.${text.substring(integerDigits)}';
  return '${_localize(mantissa, languageCode)}${_suffixes[exponent ~/ 3 - 1]}';
}

/// Formats a 0–1 ratio as a percentage with one decimal, truncated so an
/// almost-perfect model never shows `100.0%`.
String formatPercent(double ratio, {String languageCode = 'en'}) {
  final tenths = (math.max(ratio, 0) * 1000 + _epsilon).floor();
  return _localize('${tenths ~/ 10}.${tenths % 10}%', languageCode);
}

/// Formats a multiplier without trailing zeros: `2`, `1.5`, `1.25`.
String formatFactor(double factor, {String languageCode = 'en'}) {
  final text =
      factor == factor.truncateToDouble() ? '${factor.toInt()}' : '$factor';
  return _localize(text, languageCode);
}

/// Formats a duration with its two largest units: `45s`, `3m 05s`,
/// `2h 13m`, `3d 4h`. The unit letters read the same in English and Spanish.
String formatDuration(Duration duration) {
  if (duration.isNegative) return '0s';
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (duration.inHours > 0) return '${duration.inHours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  return '${seconds}s';
}

int _exponentOf(double value) {
  var exponent = (math.log(value) / math.ln10).floor();
  // log10 can be off by one ulp at exact powers of ten.
  if (math.pow(10.0, exponent) > value) exponent -= 1;
  if (math.pow(10.0, exponent + 1) <= value) exponent += 1;
  return exponent;
}

String _localize(String text, String languageCode) =>
    languageCode == 'es' ? text.replaceAll('.', ',') : text;
