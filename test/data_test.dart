import 'package:flutter_test/flutter_test.dart';
import 'package:egitici_motoru/src/data/alpha.dart';
import 'package:egitici_motoru/src/data/discover.dart';
import 'package:egitici_motoru/src/data/discover_names.dart';
import 'package:egitici_motoru/src/data/flags.dart';
import 'package:egitici_motoru/src/data/names.dart';
import 'package:egitici_motoru/src/data/titles.dart';
import 'package:egitici_motoru/src/data/turkey.dart';
import 'package:egitici_motoru/src/data/words.dart';
import 'package:egitici_motoru/src/data/world.dart';
import 'package:egitici_motoru/src/texts.dart';

void main() {
  const langs = ['tr', 'en', 'de', 'es', 'fr', 'ar', 'fa', 'he', 'ur', 'ru', 'uk', 'pl', 'cs', 'ro', 'hu', 'el', 'it', 'pt', 'nl', 'sv', 'da', 'nb', 'fi', 'ja', 'ko', 'zh', 'hi', 'bn', 'id', 'ms', 'th', 'vi', 'fil'];

  test('33 dilde metin, alfabe, nota ve hece tablosu', () {
    for (final v in kEgiticiTexts.values) {
      expect(v.length, 33);
    }
    for (final v in kNames.values) {
      expect(v.length, 33);
    }
    for (final l in langs) {
      expect(kAlphaUpper[l]!.length, greaterThanOrEqualTo(21), reason: l);
      expect(kAlphaLower[l]!.length, kAlphaUpper[l]!.length, reason: l);
      expect(kNoteNames[l]!.length, 7, reason: l);
      expect(kSyllables[l]!.length, kWordKeys.length, reason: l);
    }
    expect(kWordEmoji.length, kWordKeys.length);
  });

  test('bayrak, ülke adı ve harita verisi', () {
    for (final f in kFlags) {
      expect(kCountryNames[f[0]]!.length, 33, reason: f[0]);
    }
    final mapped = {for (final e in kWorld) e[0]};
    for (final c in kMapCountries) {
      expect(mapped.contains(c), isTrue, reason: c);
    }
    expect(kTurkey.length, 81);
    expect(kRegionNames.length, 7);
    expect(kGameTitles.length, 36);
  });

  test('meslek, vücut, dinozor, meyve-sebze verisi 33 dilde', () {
    for (final v in kDiscoverNames.values) {
      expect(v.length, 33);
    }
    for (final v in kDiscoverTexts.values) {
      expect(v.length, 33);
    }
    for (final k in kPicEmoji.keys) {
      expect(kNames.containsKey(k) || kDiscoverNames.containsKey(k), isTrue, reason: k);
    }
    for (final k in kDinoKeys) {
      expect(kDiscoverNames.containsKey(k), isTrue, reason: k);
    }
    expect(kDinoDiet.length, kDinoKeys.length);
    expect(kDinoHome.length, kDinoKeys.length);
    expect(kDinoSize.length, kDinoKeys.length);
    // her alet ve yer tek bir mesleğe aittir
    final seen = <String>{};
    for (final j in kJobs) {
      for (final e in [...j.tools, ...j.places]) {
        expect(seen.add(e), isTrue, reason: e);
      }
    }
  });
}
