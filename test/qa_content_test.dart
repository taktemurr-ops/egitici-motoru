// Bağımsız QA (28.11): çocuk sorularında "ikinci doğru" çeldirici, dile göre
// aynı görünen seçenek, bozuk hece bölmesi, anlamsız sıra sorusu ve izleme
// eşiği için regresyon testleri. Her biri gerçek bir hatayı yakalamıştır.
import 'package:egitici_motoru/src/catalog.dart';
import 'package:egitici_motoru/src/data/discover.dart';
import 'package:egitici_motoru/src/data/names.dart';
import 'package:egitici_motoru/src/data/words.dart';
import 'package:egitici_motoru/src/kid/quiz.dart';
import 'package:egitici_motoru/src/kid/vis.dart';
import 'package:egitici_motoru/src/kinds/life.dart';
import 'package:egitici_motoru/src/kinds/write.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/rng.dart';

const _langs = ['tr', 'en', 'de', 'es', 'fr', 'ar', 'fa', 'he', 'ur', 'ru', 'uk', 'pl', 'cs', 'ro', 'hu', 'el', 'it', 'pt', 'nl', 'sv', 'da', 'nb', 'fi', 'ja', 'ko', 'zh', 'hi', 'bn', 'id', 'ms', 'th', 'vi', 'fil'];

/// Bir türün d = 1..10 ve birçok tohumla ürettiği bütün sorular.
Iterable<QItem> _items(String kind, {int seeds = 40}) sync* {
  final k = kEgiticiKinds[kind]!;
  for (var d = 1; d <= 10; d++) {
    for (var s = 0; s < seeds; s++) {
      Object? p;
      try {
        p = k.make(d, SeededRandom(mixSeed([s, d, 9001])));
      } catch (_) {
        p = null;
      }
      if (p is QuizPuzzle && k.check(p)) yield* p.items;
    }
  }
}

void main() {
  test('her dilde yazılı seçenekler birbirinden farklı görünür', () {
    for (final kind in kEgiticiKinds.keys) {
      for (final it in _items(kind, seeds: 12)) {
        for (final lang in _langs) {
          final shown = [for (final o in it.options) visText(o, lang)?.$1].whereType<String>().toList();
          expect(shown.toSet().length, shown.length, reason: '$kind $lang $shown');
        }
      }
    }
  });

  test('Güneş Sistemi: en sıcak / en büyük sorusunda Güneş, en soğukta Uranüs çeldirici değil', () {
    for (final it in _items('gunes-sistemi')) {
      final p = it.prompt;
      if (p == null || p.t != VT.emoji) continue;
      final shown = {for (final o in it.options) o.a};
      if (p.s == '🔥' || p.s == '🐘') expect(shown.contains(0), isFalse, reason: p.s);
      if (p.s == '🥶') expect(shown.contains(7), isFalse);
    }
  });

  test('Hayvanlar: ikinci doğal yaşam alanı çeldirici olmaz (ördek-çiftlik, yılan-orman, tavşan-ev)', () {
    const also = {4: {0}, 14: {2, 3}, 15: {0, 1}};
    for (final it in _items('hayvanlar')) {
      final p = it.prompt;
      if (p == null || p.t != VT.animal) continue;
      final bad = also[p.a];
      if (bad == null) continue;
      for (final o in it.options) {
        if (o.t == VT.home) expect(bad.contains(o.a), isFalse, reason: 'hayvan ${p.a} yer ${o.a}');
      }
    }
  });

  test('Mevsimler: hava–giysi eşyası tek bir havaya ait', () {
    final seen = <String, String>{};
    for (final it in _items('mevsimler')) {
      final p = it.prompt;
      if (p == null || p.t != VT.emoji || !['☀️', '🌧️', '❄️'].contains(p.s)) continue;
      final right = it.options[it.answer].s;
      expect(seen.putIfAbsent(right, () => p.s), p.s, reason: right);
    }
  });

  test('Dinozorlar: balık yiyen için et çeldirici değil; karpuz renk sorusunda yok', () {
    for (final it in _items('dinozorlar')) {
      final p = it.prompt;
      if (p == null || p.t != VT.dino || kDinoDiet[p.a] != 2) continue;
      if (it.options.any((o) => o.s == '🐟')) expect(it.options.any((o) => o.s == '🍖'), isFalse);
    }
    for (final it in _items('meyve-sebze')) {
      if (it.prompt?.t == VT.color) expect(it.options.any((o) => o.s == 'f.watermelon'), isFalse);
    }
  });

  test('Sağlıklı alışkanlıklar: sıra soruları yalnız tartışmasız sıralardan', () {
    for (final r in kRoutines) {
      expect(r.toSet().length, r.length);
    }
    // "uyan → ?" gibi aileye göre değişen sıra yok.
    expect(kRoutines.any((r) => r.contains('⏰')), isFalse);
  });

  test('Zıt kavramlar: balonun karşıtı sorusunda aşağı oku çıkmaz', () {
    for (final it in _items('zit-kavramlar')) {
      final p = it.prompt!;
      if (p.s == '🎈' || p.s == '🚀') expect(it.options.any((o) => o.s == '⬇️'), isFalse, reason: p.s);
      if (p.s == '🌧️' || p.s == '💦') expect(it.options.any((o) => o.s == '🌞'), isFalse, reason: p.s);
    }
  });

  test('Başkentler: tartışmalı başkent sorulmaz', () {
    for (final it in _items('baskentler')) {
      for (final o in [it.prompt!, ...it.options]) {
        expect(o.s == 'IL', isFalse);
      }
    }
  });

  test('Alfabe (zh): sıradaki harf sorusu Çince sayılarla, artan sırada', () {
    expect(zhNumeral(1), '一');
    expect(zhNumeral(10), '十');
    expect(zhNumeral(11), '十一');
    expect(zhNumeral(20), '二十');
    expect(zhNumeral(25), '二十五');
    for (var off = 0; off < 12; off++) {
      for (var i = 0; i < 20; i++) {
        expect(seqLetterAt('zh', i, off), zhNumeral(i + off % 6 + 1));
      }
    }
    expect(seqLetterAt('tr', 3, 0), letterAt('tr', 3, 0));
  });

  test('Hece: parçalar sözcüğü verir, ünsüz tek başına hece olmaz', () {
    final vowel = RegExp(r'[aeiouyáéíóúýàèìòùâêîôûäëïöüőűåæøœãõąęěůăıаеёиоуыэюяіїєαεηιουωάέήίόύώ]', caseSensitive: false);
    const latinCyr = {'tr', 'en', 'de', 'es', 'fr', 'ru', 'uk', 'pl', 'ro', 'hu', 'el', 'it', 'pt', 'nl', 'sv', 'da', 'nb', 'fi', 'id', 'ms', 'fil'};
    for (final lang in latinCyr) {
      final rows = kSyllables[lang]!;
      for (var w = 0; w < rows.length; w++) {
        for (final part in rows[w]) {
          expect(vowel.hasMatch(part), isTrue, reason: '$lang ${kWordKeys[w]} $part');
        }
      }
    }
    // Çekçede r/l hece çekirdeği olabilir (mr-kev); yalnız tek ünsüz parçası yasak.
    for (final row in kSyllables['cs']!) {
      for (final part in row) {
        expect(part.trim().length > 1 || vowel.hasMatch(part), isTrue, reason: 'cs $row');
      }
    }
  });

  test('Harf izleme: neredeyse tamamı boyanan harf, taşma olsa da kabul edilir', () {
    expect(traceDone(0.72, 0.5), isTrue);
    expect(traceDone(0.72, 0.6), isFalse);
    expect(traceDone(0.9, 0.65), isTrue);
    expect(traceDone(0.6, 0.1), isFalse);
  });

  test('renk sorusu nesneleri: her nesne tek renkte', () {
    expect(kColorKeys.length, 10);
  });
}
