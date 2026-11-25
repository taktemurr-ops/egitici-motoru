import 'package:flutter_test/flutter_test.dart';
import 'package:egitici_motoru/src/data/capitals.dart';
import 'package:egitici_motoru/src/data/flags.dart';
import 'package:egitici_motoru/src/kid/vis.dart';

void main() {
  test('every flag has a capital name in 33 languages', () {
    for (final f in kFlags) {
      final row = kCapitalNames[f[0]];
      expect(row, isNotNull, reason: f[0]);
      expect(row!.length, 33, reason: f[0]);
      expect(row.every((x) => x.isNotEmpty), isTrue, reason: f[0]);
    }
  });

  test('capitalOf is localized', () {
    expect(capitalOf('FR', 'tr'), 'Paris');
    expect(capitalOf('JP', 'ja'), '東京');
    expect(capitalOf('EG', 'tr'), 'Kahire');
    expect(capitalOf('EG', 'en'), 'Cairo');
    expect(capitalOf('RU', 'ru'), 'Москва');
  });
}
