import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/flags.dart';
import '../data/misc.dart';
import '../data/names.dart';
import '../data/world.dart';
import '../kid/quiz.dart';
import '../kid/vis.dart';

/// Soru dizisi türlerinin ortak iskeleti.
abstract class QuizKind extends EgiticiKind {
  const QuizKind();

  int itemCount(int d) => 5 + d ~/ 2;
  int optCount(int d) => d <= 2 ? 3 : 4;
  bool get race => false;
  bool get grid => false;

  /// k. soru (kurulamazsa null).
  QItem? item(int d, SeededRandom r, int k);

  /// Türe özgü ek denetim (ör. aritmetik sonucu yeniden hesaplamak).
  bool extra(QItem it) => true;

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final items = <QItem>[];
    final seen = <String>{};
    var guard = 0;
    while (items.length < itemCount(d) && guard++ < 200) {
      final it = item(d, r, items.length);
      if (it == null) continue;
      final key = '${it.prompt?.key}|${it.options[it.answer].key}';
      if (seen.contains(key) && guard < 150) continue;
      seen.add(key);
      items.add(it);
    }
    if (items.length < itemCount(d)) return null;
    return QuizPuzzle(items, race: race, grid: grid);
  }

  @override
  bool check(EPuzzle p) => checkQuiz(p) && (p as QuizPuzzle).items.every(extra);

  @override
  Widget build(EPlay play) => QuizView(play: play, q: play.puzzle as QuizPuzzle);
}

const List<String> _countEmoji = ['🍎', '🍓', '🐞', '⭐', '🐟', '🌸', '🎈', '🍪', '🐥', '🚗', '🦋', '🍋'];

// ---------------------------------------------------------------- alfabe

class AlfabeKind extends QuizKind {
  const AlfabeKind();
  @override
  String get id => 'alfabe';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final off = r.nextInt(997);
    final t = d >= 5 ? r.nextInt(3) : (d >= 3 ? r.nextInt(2) : 0);
    final n = optCount(d);
    if (t == 2) {
      final i = r.nextInt(17);
      final ans = i + 3;
      final wrong = distinct(r, 20, n - 1, avoid: {ans});
      return qi(Vis(VT.letters, a: i, b: off, c: 3), Vis(VT.letter, a: ans, b: off), [for (final w in wrong) Vis(VT.letter, a: w, b: off)], r);
    }
    final i = r.nextInt(20);
    final wrong = distinct(r, 20, n - 1, avoid: {i});
    final lower = t == 1 ? 1 : 0;
    return qi(Vis(VT.letter, a: i, b: off), Vis(VT.letter, a: i, b: off, c: lower), [for (final w in wrong) Vis(VT.letter, a: w, b: off, c: lower)], r);
  }
}

// ---------------------------------------------------------------- sayılar

class SayiKind extends QuizKind {
  const SayiKind();
  @override
  String get id => 'sayi';

  int _max(int d) => d <= 2 ? 5 : (d <= 4 ? 10 : (d <= 7 ? 15 : 20));

  List<int> _near(SeededRandom r, int v, int n, int lo, int hi) {
    final out = <int>{};
    var g = 0;
    while (out.length < n && g++ < 200) {
      final x = v + r.range(-3, 3);
      if (x != v && x >= lo && x <= hi) out.add(x);
    }
    while (out.length < n) {
      final x = lo + r.nextInt(hi - lo + 1);
      if (x != v) out.add(x);
    }
    return out.toList();
  }

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final mx = _max(d);
    final e = r.pick(_countEmoji);
    final n = optCount(d);
    final t = d >= 4 ? r.nextInt(4) : (d >= 3 ? r.nextInt(3) : r.nextInt(2));
    switch (t) {
      case 0: {
        final v = r.range(1, mx);
        return qi(Vis(VT.count, s: e, a: v), Vis(VT.number, a: v), [for (final w in _near(r, v, n - 1, 1, mx)) Vis(VT.number, a: w)], r);
      }
      case 1: {
        final v = r.range(1, math.min<int>(mx, 12));
        return qi(Vis(VT.number, a: v), Vis(VT.count, s: e, a: v), [for (final w in _near(r, v, n - 1, 1, math.min<int>(mx, 12))) Vis(VT.count, s: e, a: w)], r);
      }
      case 2: {
        final vals = distinct(r, math.min<int>(mx, 12), math.min<int>(n, 3)).map((x) => x + 1).toList();
        final best = vals.reduce((a, b) => a > b ? a : b);
        return qi(const Vis(VT.emoji, s: '⬆️'), Vis(VT.count, s: e, a: best), [for (final w in vals) if (w != best) Vis(VT.count, s: e, a: w)], r);
      }
      default: {
        final step = d >= 9 ? r.pick(const [2, 5, 10]) : (d >= 7 ? r.pick(const [1, 2]) : 1);
        final start = r.range(0, math.max<int>(1, mx - 3 * step));
        final gap = r.nextInt(4);
        final v = start + gap * step;
        return qi(Vis(VT.numSeq, a: start, b: step, c: gap, s: '4'), Vis(VT.number, a: v), [for (final w in _near(r, v, n - 1, 0, mx + 3 * step)) Vis(VT.number, a: w)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- saat

class SaatKind extends QuizKind {
  const SaatKind();
  @override
  String get id => 'saat';

  int _min(int d, SeededRandom r) {
    if (d <= 2) return 0;
    if (d <= 4) return r.pick(const [0, 30]);
    if (d <= 6) return r.pick(const [0, 15, 30, 45]);
    return 5 * r.nextInt(12);
  }

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final h = r.range(1, 12), m = _min(d, r);
    final n = optCount(d);
    final wrong = <(int, int)>{};
    var g = 0;
    while (wrong.length < n - 1 && g++ < 100) {
      final kind = r.nextInt(3);
      final w = kind == 0 ? (r.range(1, 12), m) : (kind == 1 ? (h, _min(d, r)) : (m == 0 ? 12 : clampI(m ~/ 5, 1, 12), h * 5 % 60));
      if (w != (h, m) && w.$1 >= 1 && w.$1 <= 12) wrong.add(w);
    }
    if (wrong.length < n - 1) return null;
    final digital = r.nextBool2(d);
    if (digital) {
      return qi(Vis(VT.clock, a: h, b: m), Vis(VT.digital, a: h, b: m), [for (final w in wrong) Vis(VT.digital, a: w.$1, b: w.$2)], r);
    }
    return qi(Vis(VT.digital, a: h, b: m), Vis(VT.clock, a: h, b: m), [for (final w in wrong) Vis(VT.clock, a: w.$1, b: w.$2)], r);
  }
}

extension on SeededRandom {
  /// Düşük zorlukta çoğunlukla saatten dijitale; sonra karışık.
  bool nextBool2(int d) => d <= 2 ? chance(0.75) : chance(0.5);
}

// ---------------------------------------------------------------- şekil ve renk

const List<List<String>> _colorThings = [
  ['🍎', '🍓', '🍒', '🚒'],
  ['🍊', '🥕', '🦊', '🏀'],
  ['🍌', '🍋', '🌻', '🐥'],
  ['🥦', '🐸', '🍀', '🥒'],
  ['🌊', '🐳', '💧', '🧢'],
  ['🍇', '🍆', '☂️', '🔮'],
  ['🌸', '🦩', '🎀', '🌷'],
  ['🐻', '🌰', '🥔', '🍫'],
  ['🐜', '🎩', '🕷️', '🎱'],
  ['⛄', '🥛', '☁️', '🦢'],
];

class SekilRenkKind extends QuizKind {
  const SekilRenkKind();
  @override
  String get id => 'sekil-renk';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final t = d >= 5 ? r.nextInt(3) : (d >= 2 ? r.nextInt(2) : 0);
    switch (t) {
      case 0: {
        final sh = r.nextInt(d <= 3 ? 6 : 10), col = r.nextInt(8);
        final wrong = <Vis>{};
        var g = 0;
        while (wrong.length < n - 1 && g++ < 100) {
          final ws = d >= 4 && r.chance(0.5) ? sh : r.nextInt(d <= 3 ? 6 : 10);
          final wc = ws == sh ? (col + 1 + r.nextInt(7)) % 8 : (d >= 4 ? r.nextInt(8) : col);
          final v = Vis(VT.shape, a: ws, b: wc);
          if (v.key != Vis(VT.shape, a: sh, b: col).key) wrong.add(v);
        }
        return qi(Vis(VT.shape, a: sh, b: col), Vis(VT.shape, a: sh, b: col), _uniq(wrong.toList()), r);
      }
      case 1: {
        final col = r.nextInt(10);
        final others = distinct(r, 10, n - 1, avoid: {col});
        return qi(Vis(VT.color, a: col, c: d >= 4 ? 1 : 0), Vis(VT.emoji, s: r.pick(_colorThings[col])),
            [for (final o in others) Vis(VT.emoji, s: r.pick(_colorThings[o]))], r);
      }
      default: {
        final col = r.nextInt(10);
        final others = distinct(r, 10, n - 1, avoid: {col});
        return qi(Vis(VT.colorName, a: col), Vis(VT.color, a: col), [for (final o in others) Vis(VT.color, a: o)], r);
      }
    }
  }
}

List<Vis> _uniq(List<Vis> xs) {
  final seen = <String>{};
  return [for (final x in xs) if (seen.add(x.key)) x];
}

// ---------------------------------------------------------------- geometri

const List<(String, int)> _solidThings = [('🎲', 0), ('📦', 0), ('🧊', 0), ('⚽', 1), ('🏀', 1), ('🌍', 1), ('🥫', 2), ('🔋', 2), ('🥁', 2), ('🍦', 3), ('🥕', 3)];

class GeometriKind extends QuizKind {
  const GeometriKind();
  @override
  String get id => 'geometri';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final t = r.nextInt(d >= 3 ? 4 : 2);
    switch (t) {
      case 0: {
        final sh = r.nextInt(10), col = r.nextInt(8);
        final others = distinct(r, 10, n - 1, avoid: {sh});
        return qi(Vis(VT.shape, a: sh, b: col), Vis(VT.shapeName, a: sh), [for (final o in others) Vis(VT.shapeName, a: o)], r);
      }
      case 1: {
        final st = r.pick(_solidThings);
        final others = distinct(r, 4, math.min<int>(n - 1, 3), avoid: {st.$2});
        return qi(Vis(VT.emoji, s: st.$1), Vis(VT.shape3, a: st.$2, c: 1), [for (final o in others) Vis(VT.shape3, a: o, c: 1)], r);
      }
      case 2: {
        const poly = [1, 2, 3, 7, 8, 9];
        final sh = r.pick(poly);
        final sides = shapeSides(sh);
        final wrong = <int>{};
        while (wrong.length < n - 1) {
          final w = r.range(3, 8);
          if (w != sides) wrong.add(w);
        }
        return qi(Vis(VT.shape, a: sh, b: r.nextInt(8)), Vis(VT.number, a: sides), [for (final w in wrong) Vis(VT.number, a: w)], r);
      }
      default: {
        final s3 = r.nextInt(4);
        final others = distinct(r, 4, math.min<int>(n - 1, 3), avoid: {s3});
        return qi(Vis(VT.shape3, a: s3), Vis(VT.shapeName, a: 10 + s3), [for (final o in others) Vis(VT.shapeName, a: 10 + o)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- aritmetik

int _apply(int a, int b, int op) => switch (op) { 0 => a + b, 1 => a - b, 2 => a * b, _ => b == 0 ? 0 : a ~/ b };

bool _eqOk(QItem it) {
  final p = it.prompt;
  if (p == null) return true;
  final ans = it.options[it.answer];
  if (p.t == VT.eq && ans.t == VT.number) return _apply(p.a, p.b, p.c) == ans.a;
  if (p.t == VT.dots && ans.t == VT.number) return p.a * p.b == ans.a;
  return true;
}

List<Vis> _numWrong(SeededRandom r, int v, int n, {int spread = 4}) {
  final out = <int>{};
  var g = 0;
  while (out.length < n && g++ < 300) {
    final x = v + r.range(-spread, spread);
    if (x != v && x >= 0) out.add(x);
  }
  while (out.length < n) {
    out.add(v + out.length + 1);
  }
  return [for (final x in out) Vis(VT.number, a: x)];
}

QItem _eqItem(SeededRandom r, int a, int b, int op, int n, {String emoji = ''}) {
  final v = _apply(a, b, op);
  return qi(Vis(VT.eq, a: a, b: b, c: op, s: emoji), Vis(VT.number, a: v), _numWrong(r, v, n - 1, spread: math.max<int>(3, v ~/ 6)), r);
}

class MatematikYarisiKind extends QuizKind {
  const MatematikYarisiKind();
  @override
  String get id => 'matematik-yarisi';
  @override
  bool get race => true;
  @override
  int itemCount(int d) => 8 + d ~/ 3;
  @override
  bool extra(QItem it) => _eqOk(it);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    if (d <= 3) {
      final a = r.range(1, 6), b = r.range(1, 4);
      return _eqItem(r, a, b, 0, n);
    }
    final mx = d <= 6 ? 20 : 50;
    final op = d >= 9 ? r.nextInt(3) : r.nextInt(2);
    if (op == 2) return _eqItem(r, r.range(2, 9), r.range(2, 9), 2, n);
    final a = r.range(2, mx), b = r.range(1, mx ~/ 2);
    if (op == 1) return _eqItem(r, math.max<int>(a, b), math.min<int>(a, b), 1, n);
    return _eqItem(r, a, b, 0, n);
  }
}

class CarpimKind extends QuizKind {
  const CarpimKind();
  @override
  String get id => 'carpim';
  @override
  bool extra(QItem it) => _eqOk(it);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final tables = d <= 1
        ? const [1, 2, 5, 10]
        : d <= 3
            ? const [2, 3, 4, 5]
            : d <= 5
                ? const [3, 4, 6, 7]
                : const [6, 7, 8, 9];
    final a = r.pick(tables), b = r.range(1, d <= 6 ? 10 : 10);
    if (d <= 4 && r.chance(0.45) && a <= 6 && b <= 6) {
      return qi(Vis(VT.dots, a: a, b: b), Vis(VT.number, a: a * b), _numWrong(r, a * b, n - 1, spread: math.max<int>(2, a)), r);
    }
    return _eqItem(r, a, b, 2, n);
  }
}

class ToplamaCikarmaKind extends QuizKind {
  const ToplamaCikarmaKind();
  @override
  String get id => 'toplama-cikarma';
  @override
  bool extra(QItem it) => _eqOk(it);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final sub = d >= 3 && r.chance(0.5);
    if (d <= 3) {
      final a = r.range(1, 5), b = r.range(1, 4);
      final e = r.pick(_countEmoji);
      if (sub) return _eqItem(r, math.max<int>(a, b), math.min<int>(a, b), 1, n, emoji: e);
      return _eqItem(r, a, b, 0, n, emoji: d <= 2 ? e : '');
    }
    final mx = d <= 5 ? 10 : (d <= 7 ? 20 : 100);
    final a = r.range(1, mx), b = r.range(1, mx);
    if (sub) return _eqItem(r, math.max<int>(a, b), math.min<int>(a, b), 1, n);
    return _eqItem(r, a, b, 0, n);
  }
}

// ---------------------------------------------------------------- kesirler

class KesirKind extends QuizKind {
  const KesirKind();
  @override
  String get id => 'kesirler';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final dens = d <= 3 ? const [2, 3, 4] : (d <= 6 ? const [2, 3, 4, 5, 6, 8] : const [3, 4, 5, 6, 8, 10, 12]);
    final n = optCount(d);
    final t = d >= 5 ? r.nextInt(3) : r.nextInt(2);
    final den = r.pick(dens), nu = r.range(1, den - 1 < 1 ? 1 : den - 1);
    final bar = r.chance(0.4) ? 1 : 0;
    final wrong = <(int, int)>{};
    var g = 0;
    while (wrong.length < n - 1 && g++ < 200) {
      final wd = r.chance(0.5) ? den : r.pick(dens);
      final wn = r.range(1, math.max<int>(1, wd - 1));
      if (wn * den != nu * wd) wrong.add((wn, wd));
    }
    if (wrong.length < n - 1) return null;
    if (t == 2) {
      final vals = <(int, int)>[(nu, den), ...wrong.take(math.min<int>(2, n - 1))];
      vals.sort((x, y) => (y.$1 * x.$2).compareTo(x.$1 * y.$2));
      final best = vals.first;
      if (vals.length > 1 && best.$1 * vals[1].$2 == vals[1].$1 * best.$2) return null;
      return qi(const Vis(VT.emoji, s: '⬆️'), Vis(VT.frac, a: best.$1, b: best.$2, c: bar), [for (final w in vals.skip(1)) Vis(VT.frac, a: w.$1, b: w.$2, c: bar)], r);
    }
    if (t == 0) {
      return qi(Vis(VT.frac, a: nu, b: den, c: bar), Vis(VT.fracText, a: nu, b: den), [for (final w in wrong) Vis(VT.fracText, a: w.$1, b: w.$2)], r);
    }
    return qi(Vis(VT.fracText, a: nu, b: den), Vis(VT.frac, a: nu, b: den, c: bar), [for (final w in wrong) Vis(VT.frac, a: w.$1, b: w.$2, c: bar)], r);
  }
}

// ---------------------------------------------------------------- para

class ParaKind extends QuizKind {
  const ParaKind();
  @override
  String get id => 'para-sayma';

  List<int> _purse(int d, SeededRandom r) {
    final vals = d <= 3 ? const [1, 2, 5] : (d <= 6 ? const [1, 2, 5, 10] : const [1, 2, 5, 10, 20, 50, 100]);
    final n = d <= 2 ? r.range(2, 3) : r.range(2, d <= 6 ? 5 : 6);
    final out = [for (var i = 0; i < n; i++) r.pick(vals)]..sort((a, b) => b.compareTo(a));
    return out;
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt, a = it.options[it.answer];
    int sum(String s) => s.split(',').map((x) => int.tryParse(x) ?? 0).fold(0, (x, y) => x + y);
    if (p != null && p.t == VT.coins && a.t == VT.money) return sum(p.s) == a.a;
    if (p != null && p.t == VT.money && a.t == VT.coins) return sum(a.s) == p.a;
    return true;
  }

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final purse = _purse(d, r);
    final total = purse.fold<int>(0, (a, b) => a + b);
    if (r.chance(0.5)) {
      final wrong = <int>{};
      var g = 0;
      while (wrong.length < n - 1 && g++ < 200) {
        final w = total + r.range(-math.max<int>(3, total ~/ 4), math.max<int>(3, total ~/ 4));
        if (w > 0 && w != total) wrong.add(w);
      }
      return qi(Vis(VT.coins, s: purse.join(',')), Vis(VT.money, a: total), [for (final w in wrong) Vis(VT.money, a: w)], r);
    }
    final wrong = <String, int>{};
    var g = 0;
    while (wrong.length < n - 1 && g++ < 300) {
      final p2 = _purse(d, r);
      final t2 = p2.fold<int>(0, (a, b) => a + b);
      if (t2 != total) wrong[p2.join(',')] = t2;
    }
    if (wrong.length < n - 1) return null;
    return qi(Vis(VT.money, a: total), Vis(VT.coins, s: purse.join(',')), [for (final w in wrong.keys) Vis(VT.coins, s: w)], r);
  }
}

// ---------------------------------------------------------------- bayraklar ve haritalar

class BayrakKind extends QuizKind {
  const BayrakKind();
  @override
  String get id => 'bayraklar';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final pool = d <= 3 ? 30 : (d <= 6 ? 50 : kFlags.length);
    final n = optCount(d);
    final idx = distinct(r, pool, n);
    final codes = [for (final i in idx) kFlags[i][0]];
    if (r.chance(0.6)) {
      return qi(Vis(VT.flag, s: codes[0]), Vis(VT.country, s: codes[0]), [for (final c in codes.skip(1)) Vis(VT.country, s: c)], r);
    }
    return qi(Vis(VT.country, s: codes[0]), Vis(VT.flag, s: codes[0]), [for (final c in codes.skip(1)) Vis(VT.flag, s: c)], r);
  }
}

class BaskentKind extends QuizKind {
  const BaskentKind();
  @override
  String get id => 'baskentler';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final pool = d <= 3 ? math.min<int>(30, kMapCountries.length) : kMapCountries.length;
    final n = optCount(d);
    final codes = [for (final i in distinct(r, pool, n)) kMapCountries[i]];
    final t = d >= 5 ? r.nextInt(3) : r.nextInt(2);
    switch (t) {
      case 0: {
        return qi(Vis(VT.mapc, s: codes[0]), Vis(VT.country, s: codes[0]), [for (final c in codes.skip(1)) Vis(VT.country, s: c)], r);
      }
      case 1: {
        return qi(Vis(VT.country, s: codes[0]), Vis(VT.capital, s: codes[0]), [for (final c in codes.skip(1)) Vis(VT.capital, s: c)], r);
      }
      default: {
        return qi(Vis(VT.capital, s: codes[0]), Vis(VT.mapc, s: codes[0]), [for (final c in codes.skip(1)) Vis(VT.mapc, s: c)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- güneş sistemi

const List<(String, int)> _planetFacts = [('🏠', 3), ('🔴', 4), ('🪐', 6), ('🔥', 2), ('🐘', 5), ('🥶', 8), ('☀️', 0), ('🌙', 9)];

class GunesKind extends QuizKind {
  const GunesKind();
  @override
  String get id => 'gunes-sistemi';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final t = d >= 3 ? r.nextInt(3) : (r.chance(0.5) ? 0 : 2);
    switch (t) {
      case 0: {
        final p = r.nextInt(10);
        final others = distinct(r, 10, n - 1, avoid: {p});
        return qi(Vis(VT.planet, a: p), Vis(VT.planetName, a: p), [for (final o in others) Vis(VT.planetName, a: o)], r);
      }
      case 1: {
        final k2 = r.range(1, 8);
        final others = [for (final o in distinct(r, 8, n - 1, avoid: {k2 - 1})) o + 1];
        return qi(Vis(VT.orbit, a: k2), Vis(VT.planet, a: k2), [for (final o in others) Vis(VT.planet, a: o)], r);
      }
      default: {
        final f = r.pick(_planetFacts);
        final others = distinct(r, 10, n - 1, avoid: {f.$2});
        return qi(Vis(VT.emoji, s: f.$1), Vis(VT.planet, a: f.$2, c: d >= 4 ? 1 : 0), [for (final o in others) Vis(VT.planet, a: o, c: d >= 4 ? 1 : 0)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- mevsimler ve hava

const List<List<String>> _seasonThings = [
  ['🌷', '🐣', '🌸', '🦋', '🌱'],
  ['🏖️', '🍉', '🍦', '🕶️', '🌞'],
  ['🍂', '🍁', '🌰', '🍄', '🧺'],
  ['⛄', '❄️', '🧣', '🛷', '🧤'],
];
const List<String> _seasonIcon = ['🌸', '☀️', '🍂', '❄️'];
const List<(String, List<String>)> _weatherWear = [
  ('☀️', ['🕶️', '🧢', '🩳']),
  ('🌧️', ['☂️', '👢', '🧥']),
  ('❄️', ['🧤', '🧣', '🥾']),
];

class MevsimKind extends QuizKind {
  const MevsimKind();
  @override
  String get id => 'mevsimler';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final t = d >= 4 ? r.nextInt(3) : r.nextInt(2);
    switch (t) {
      case 0: {
        final s = r.nextInt(4);
        final others = distinct(r, 4, math.min<int>(optCount(d), 4) - 1, avoid: {s});
        return qi(Vis(VT.emoji, s: r.pick(_seasonThings[s])), Vis(VT.season, a: s, c: 1), [for (final o in others) Vis(VT.season, a: o, c: 1)], r);
      }
      case 1: {
        final w = r.nextInt(_weatherWear.length);
        final right = r.pick(_weatherWear[w].$2);
        final wrong = <String>[];
        for (var i = 0; i < _weatherWear.length; i++) {
          if (i != w) wrong.add(r.pick(_weatherWear[i].$2));
        }
        return qi(Vis(VT.emoji, s: _weatherWear[w].$1), Vis(VT.emoji, s: right), [for (final x in wrong) Vis(VT.emoji, s: x)], r);
      }
      default: {
        final s = r.nextInt(4);
        final nx = (s + 1) % 4;
        final others = [for (var i = 0; i < 4; i++) if (i != nx) i];
        return qi(Vis(VT.text, s: '${_seasonIcon[s]} ➜ ?'), Vis(VT.season, a: nx, c: 1), [for (final o in others) Vis(VT.season, a: o, c: 1)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- trafik

const List<String> _actions = ['✋', '⏳', '🚶'];
const List<(String, bool)> _scenes = [
  ('🚦🧒🤝', true),
  ('🦓🚶', true),
  ('🚴⛑️', true),
  ('🚗🧒🔒', true),
  ('⚽🚗', false),
  ('🏃🚗', false),
  ('📱🚶🚗', false),
  ('🛹🚗', false),
];

class TrafikKind extends QuizKind {
  const TrafikKind();
  @override
  String get id => 'trafik';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final t = d >= 4 ? r.nextInt(3) : (r.chance(0.5) ? 0 : 2);
    switch (t) {
      case 0: {
        final l = r.nextInt(3);
        final act = l == 0 ? 0 : (l == 1 ? 1 : 2);
        return qi(Vis(VT.light, a: l), Vis(VT.emoji, s: _actions[act]), [for (var i = 0; i < 3; i++) if (i != act) Vis(VT.emoji, s: _actions[i])], r);
      }
      case 1: {
        final sg = r.nextInt(8);
        final others = distinct(r, 8, optCount(d) - 1, avoid: {sg});
        return qi(Vis(VT.sign, a: sg), Vis(VT.signName, a: sg), [for (final o in others) Vis(VT.signName, a: o)], r);
      }
      default: {
        final sc = r.pick(_scenes);
        return qi(Vis(VT.text, s: sc.$1), Vis(VT.emoji, s: sc.$2 ? '✅' : '❌'), [Vis(VT.emoji, s: sc.$2 ? '❌' : '✅')], r);
      }
    }
  }
}

// ---------------------------------------------------------------- hayvanlar ve sesleri

class HayvanKind extends QuizKind {
  const HayvanKind();
  @override
  String get id => 'hayvanlar';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final t = d >= 5 ? r.nextInt(3) : (d >= 2 ? r.nextInt(2) : 0);
    switch (t) {
      case 0: {
        final a = r.nextInt(kAnimalSound.length);
        final others = distinct(r, kAnimalEmoji.length, n - 1, avoid: {a});
        return qi(Vis(VT.sound, a: a), Vis(VT.animal, a: a), [for (final o in others) Vis(VT.animal, a: o)], r, sound: 'animal_${kAnimalSound[a]}');
      }
      case 1: {
        final a = r.nextInt(kAnimalEmoji.length);
        final home = kAnimalHome[a];
        final others = distinct(r, kHomeEmoji.length, math.min<int>(n - 1, 3), avoid: {home});
        return qi(Vis(VT.animal, a: a), Vis(VT.home, a: home), [for (final o in others) Vis(VT.home, a: o)], r);
      }
      default: {
        final a = r.nextInt(kAnimalEmoji.length);
        final others = distinct(r, kAnimalEmoji.length, n - 1, avoid: {a});
        return qi(Vis(VT.animalName, a: a), Vis(VT.animal, a: a), [for (final o in others) Vis(VT.animal, a: o)], r);
      }
    }
  }
}

// ---------------------------------------------------------------- İngilizce kelime kartları

class IngilizceKind extends QuizKind {
  const IngilizceKind();
  @override
  String get id => 'ingilizce';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final pool = math.min<int>(kEnglishWords.length, 24 + d * 6);
    final idx = distinct(r, pool, optCount(d));
    if (r.chance(0.55)) {
      return qi(Vis(VT.emoji, s: kEnglishWords[idx[0]][0]), Vis(VT.text, s: kEnglishWords[idx[0]][1]), [for (final i in idx.skip(1)) Vis(VT.text, s: kEnglishWords[i][1])], r);
    }
    return qi(Vis(VT.text, s: kEnglishWords[idx[0]][1]), Vis(VT.emoji, s: kEnglishWords[idx[0]][0]), [for (final i in idx.skip(1)) Vis(VT.emoji, s: kEnglishWords[i][0])], r);
  }
}

// ---------------------------------------------------------------- dikkat geliştirme

const List<(String, String)> _lookAlike = [
  ('🐶', '🐱'),
  ('🍎', '🍅'),
  ('🐢', '🐊'),
  ('🍋', '🍌'),
  ('⭐', '🌟'),
  ('🐝', '🐞'),
  ('🌳', '🌲'),
  ('🚗', '🚕'),
  ('🐑', '🐐'),
  ('🍪', '🥯'),
  ('🐻', '🐼'),
  ('🌸', '🌼'),
];
const List<String> _asym = ['🐌', '🐢', '🦆', '🚗', '🐟', '🦒', '🐘', '🚲', '🐳', '🦕', '🐿️', '🚂', '🛴', '🐊'];

class DikkatKind extends QuizKind {
  const DikkatKind();
  @override
  String get id => 'dikkat';
  @override
  bool get grid => true;
  @override
  int itemCount(int d) => 6 + d ~/ 3;

  int _cells(int d) => d <= 1 ? 4 : (d <= 3 ? 6 : (d <= 5 ? 9 : (d <= 8 ? 12 : 16)));

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = _cells(d);
    Vis base, odd;
    if (d <= 3) {
      final pair = distinct(r, _countEmoji.length, 2);
      base = Vis(VT.emoji, s: _countEmoji[pair[0]]);
      odd = Vis(VT.emoji, s: _countEmoji[pair[1]]);
    } else if (d <= 6) {
      final p = r.pick(_lookAlike);
      final flip = r.chance(0.5);
      base = Vis(VT.emoji, s: flip ? p.$2 : p.$1);
      odd = Vis(VT.emoji, s: flip ? p.$1 : p.$2);
    } else {
      final e = r.pick(_asym);
      base = Vis(VT.emoji, s: e);
      odd = Vis(VT.emoji, s: e, c: d >= 9 && r.chance(0.5) ? 2 : 1);
    }
    final at = r.nextInt(n);
    return QItem(null, [for (var i = 0; i < n; i++) i == at ? odd : base], at);
  }
}
