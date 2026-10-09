import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:test/test.dart';

void main() {
  group('formatAmount', () {
    test('keeps one decimal below 100', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(0.5), '0.5');
      expect(formatAmount(12), '12');
      expect(formatAmount(12.34), '12.3');
      expect(formatAmount(99.99), '99.9');
    });

    test('shows whole numbers up to 999', () {
      expect(formatAmount(100), '100');
      expect(formatAmount(356.9), '356');
      expect(formatAmount(999.99), '999');
    });

    test('uses three significant digits and a suffix from 1000', () {
      expect(formatAmount(1000), '1.00K');
      expect(formatAmount(1230), '1.23K');
      expect(formatAmount(12345), '12.3K');
      expect(formatAmount(123456), '123K');
      expect(formatAmount(1e6), '1.00M');
      expect(formatAmount(1.5e9), '1.50B');
      expect(formatAmount(2.5e12), '2.50T');
      expect(formatAmount(7.89e35), '789Dc');
    });

    test('truncates instead of rounding up', () {
      expect(formatAmount(1999), '1.99K');
      expect(formatAmount(999999), '999K');
      expect(formatAmount(999999999), '999M');
    });

    test('switches to scientific notation past the last suffix', () {
      expect(formatAmount(1e36), '1.00e36');
      expect(formatAmount(4.56e100), '4.56e100');
    });

    test('uses a decimal comma in Spanish', () {
      expect(formatAmount(1230, languageCode: 'es'), '1,23K');
      expect(formatAmount(0.5, languageCode: 'es'), '0,5');
      expect(formatAmount(356, languageCode: 'es'), '356');
    });

    test('handles negative and non-finite values', () {
      expect(formatAmount(-1500), '-1.50K');
      expect(formatAmount(double.infinity), '∞');
      expect(formatAmount(double.nan), '-');
    });
  });

  test('formatPercent truncates to one decimal', () {
    expect(formatPercent(0.42), '42.0%');
    expect(formatPercent(0.99999), '99.9%');
    expect(formatPercent(0.425, languageCode: 'es'), '42,5%');
    expect(formatPercent(-0.1), '0.0%');
  });

  test('formatFactor drops trailing zeros', () {
    expect(formatFactor(2), '2');
    expect(formatFactor(1.5), '1.5');
    expect(formatFactor(1.25, languageCode: 'es'), '1,25');
  });

  test('formatDuration shows the two largest units', () {
    expect(formatDuration(const Duration(seconds: 45)), '45s');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3m 05s');
    expect(formatDuration(const Duration(hours: 2, minutes: 13)), '2h 13m');
    expect(formatDuration(const Duration(days: 3, hours: 4)), '3d 4h');
    expect(formatDuration(const Duration(seconds: -5)), '0s');
  });
}
