import 'package:flutter_test/flutter_test.dart';
import 'package:neural_idle/l10n/app_localizations_en.dart';
import 'package:neural_idle/l10n/app_localizations_es.dart';

void main() {
  test('phase 2 placeholders and plural forms are localized', () {
    final en = AppLocalizationsEn();
    final es = AppLocalizationsEs();
    expect(en.ratePerSecond('90'), '+90/s');
    expect(es.buyQuantity('10'), 'Comprar ×10');
    expect(en.offlineEvolved(0), contains('did not evolve'));
    expect(en.offlineEvolved(1), contains('once'));
    expect(en.offlineEvolved(3), contains('3 times'));
    expect(es.offlineEvolved(0), contains('no evolucionó'));
    expect(es.offlineEvolved(1), contains('una vez'));
    expect(es.offlineEvolved(3), contains('3 veces'));
    expect(es.networkSemanticLabel('CNN'), 'Red neuronal: CNN');
  });
}
