import 'package:studio_core/core/rng.dart';

import '../data/discover.dart';
import '../kid/quiz.dart';
import '../kid/vis.dart';
import 'quizzes.dart';

// Meslekler, Vücudumuz, Dinozorlar, Meyve ve Sebzeler: resimli soru dizileri.
// Her soru, verideki ilişkiden (alet → meslek, duyu → organ, dinozor → besin…)
// kurulur ve [extra] ile aynı ilişki yeniden hesaplanarak doğrulanır.

/// [pool] içinden [avoid] dışında [n] farklı öğe.
List<int> _pickOthers(SeededRandom r, List<int> pool, int n, bool Function(int) bad) {
  final xs = [for (final p in pool) if (!bad(p)) p];
  r.shuffle(xs);
  return xs.take(n).toList();
}

// ---------------------------------------------------------------- meslekler

class MeslekKind extends QuizKind {
  const MeslekKind();
  @override
  String get id => 'meslekler';

  /// Zorluğa göre açılan meslek sayısı.
  int jobs(int d) => d <= 1 ? 8 : (d <= 3 ? 11 : kJobs.length);

  Vis _person(int j, SeededRandom r, int d) => Vis(VT.pic, s: kJobs[j].key, b: r.nextInt(6), c: d >= 5 ? 1 : 0);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final pool = List<int>.generate(jobs(d), (i) => i);
    final j = r.nextInt(pool.length);
    final others = _pickOthers(r, pool, n - 1, (x) => x == j);
    if (others.length < n - 1) return null;
    final types = d <= 1 ? 2 : (d <= 3 ? 3 : 4);
    final job = kJobs[j];
    switch (r.nextInt(types)) {
      case 0: {
        // alet → kişi
        return qi(Vis(VT.emoji, s: r.pick(job.tools)), _person(j, r, d), [for (final o in others) _person(o, r, d)], r);
      }
      case 1: {
        // kişi → alet
        return qi(_person(j, r, d), Vis(VT.emoji, s: r.pick(job.tools)), [for (final o in others) Vis(VT.emoji, s: r.pick(kJobs[o].tools))], r);
      }
      case 2: {
        // kişi → çalıştığı yer
        return qi(_person(j, r, d), Vis(VT.emoji, s: r.pick(job.places)), [for (final o in others) Vis(VT.emoji, s: r.pick(kJobs[o].places))], r);
      }
      default: {
        // meslek adı → kişi
        return qi(Vis(VT.picName, s: job.key), _person(j, r, 0), [for (final o in others) _person(o, r, 0)], r);
      }
    }
  }

  /// Bir görselin ait olduğu meslek (-1: yok).
  static int jobOf(Vis v) {
    switch (v.t) {
      case VT.pic:
      case VT.picName:
        return jobOfKey(v.s);
      case VT.emoji: {
        final t = jobOfTool(v.s);
        return t >= 0 ? t : jobOfPlace(v.s);
      }
      default:
        return -1;
    }
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    final j = jobOf(p);
    if (j < 0 || jobOf(it.options[it.answer]) != j) return false;
    for (var i = 0; i < it.options.length; i++) {
      if (i == it.answer) continue;
      final o = jobOf(it.options[i]);
      if (o < 0 || o == j) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- vücudumuz

class VucutKind extends QuizKind {
  const VucutKind();
  @override
  String get id => 'vucudumuz';

  @override
  int optCount(int d) => d <= 1 ? 3 : (d <= 4 ? 4 : 5);

  Vis _part(int i, int d) => Vis(VT.pic, s: kBodyKeys[i], c: d >= 6 ? 1 : 0);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final types = d <= 1 ? 2 : (d <= 3 ? 3 : 4);
    switch (r.nextInt(types)) {
      case 0: {
        // duyulan şey → duyu organı
        final s = r.nextInt(kSenseThings.length);
        final others = _pickOthers(r, const [0, 1, 2, 3, 4], n - 1, (x) => x == s);
        return qi(Vis(VT.emoji, s: r.pick(kSenseThings[s])), _part(s, d), [for (final o in others) _part(o, d)], r);
      }
      case 1: {
        // duyu organı → onunla algılanan şey
        final s = r.nextInt(kSenseThings.length);
        final others = _pickOthers(r, const [0, 1, 2, 3, 4], n - 1, (x) => x == s);
        return qi(_part(s, 0), Vis(VT.emoji, s: r.pick(kSenseThings[s])), [for (final o in others) Vis(VT.emoji, s: r.pick(kSenseThings[o]))], r);
      }
      case 2: {
        // yapılan iş → organ
        final keys = kBodyJobs.keys.toList();
        final b = r.pick(keys);
        final others = _pickOthers(r, keys, n - 1, (x) => x == b || bodyClash(x, b));
        if (others.length < n - 1) return null;
        return qi(Vis(VT.emoji, s: r.pick(kBodyJobs[b]!)), _part(b, d), [for (final o in others) _part(o, d)], r);
      }
      default: {
        // ad → resim
        final b = r.nextInt(kBodyKeys.length);
        final others = _pickOthers(r, List<int>.generate(kBodyKeys.length, (i) => i), n - 1, (x) => x == b || bodyClash(x, b));
        return qi(Vis(VT.picName, s: kBodyKeys[b]), _part(b, 0), [for (final o in others) _part(o, 0)], r);
      }
    }
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    int partOf(Vis v) => v.t == VT.pic || v.t == VT.picName ? kBodyKeys.indexOf(v.s) : -1;
    final right = it.options[it.answer];
    if (p.t == VT.emoji) {
      final s = senseOf(p.s);
      final b = s >= 0 ? s : bodyJobOf(p.s);
      if (b < 0 || partOf(right) != b) return false;
      for (var i = 0; i < it.options.length; i++) {
        if (i == it.answer) continue;
        final o = partOf(it.options[i]);
        if (o < 0 || o == b || (s < 0 && bodyClash(o, b))) return false;
      }
      return true;
    }
    final b = partOf(p);
    if (b < 0) return false;
    if (p.t == VT.picName) {
      if (partOf(right) != b) return false;
      for (var i = 0; i < it.options.length; i++) {
        if (i == it.answer) continue;
        final o = partOf(it.options[i]);
        if (o < 0 || o == b || bodyClash(o, b)) return false;
      }
      return true;
    }
    // organ → algılanan şey
    if (b > 4 || senseOf(right.s) != b) return false;
    for (var i = 0; i < it.options.length; i++) {
      if (i == it.answer) continue;
      final o = senseOf(it.options[i].s);
      if (o < 0 || o == b) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- dinozorlar

class DinoKind extends QuizKind {
  const DinoKind();
  @override
  String get id => 'dinozorlar';

  int dinos(int d) => d <= 1 ? 6 : (d <= 3 ? 8 : kDinoKeys.length);

  Vis _dino(int i, int d) => Vis(VT.dino, a: i, c: d >= 4 ? 1 : 0);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final pool = List<int>.generate(dinos(d), (i) => i);
    final i = r.nextInt(pool.length);
    final tip = notDino(i) ? 'tip.notdino' : '';
    final types = d <= 1 ? 2 : (d <= 3 ? 3 : 4);
    switch (r.nextInt(types)) {
      case 0: {
        // ne yerdi?
        final diet = kDinoDiet[i];
        // Balık yiyen için "et" çeldirici değildir (balık da ettir): yalnız bitki.
        return qi(_dino(i, d), Vis(VT.emoji, s: kDietEmoji[diet]), [for (var x = 0; x < 3; x++) if (x != diet && !(diet == 2 && x == 1)) Vis(VT.emoji, s: kDietEmoji[x])], r,
            tip: tip, tipVis: tip.isEmpty ? null : _dino(i, 1));
      }
      case 1: {
        // en büyük hangisi? (fark en az 2 m olsun)
        final n = d <= 2 ? 2 : 3;
        for (var tries = 0; tries < 20; tries++) {
          final xs = _pickOthers(r, pool, n, (x) => false);
          xs.sort((a, b) => kDinoSize[b].compareTo(kDinoSize[a]));
          if (xs.length < n || kDinoSize[xs[0]] - kDinoSize[xs[1]] < 20) continue;
          return qi(Vis(VT.emoji, s: '📏'), _dino(xs[0], d), [for (final x in xs.skip(1)) _dino(x, d)], r);
        }
        return null;
      }
      case 2: {
        // nerede yaşardı?
        final home = kDinoHome[i];
        return qi(_dino(i, d), Vis(VT.emoji, s: kHomeIcon[home]), [for (var x = 0; x < 3; x++) if (x != home) Vis(VT.emoji, s: kHomeIcon[x])], r,
            tip: tip, tipVis: tip.isEmpty ? null : _dino(i, 1));
      }
      default: {
        // ad → resim
        final n = optCount(d);
        final others = _pickOthers(r, pool, n - 1, (x) => x == i);
        return qi(Vis(VT.picName, s: kDinoKeys[i]), _dino(i, 0), [for (final o in others) _dino(o, 0)], r);
      }
    }
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    final right = it.options[it.answer];
    if (p.t == VT.emoji && p.s == '📏') {
      if (right.t != VT.dino) return false;
      for (var i = 0; i < it.options.length; i++) {
        if (i == it.answer) continue;
        final o = it.options[i];
        if (o.t != VT.dino || kDinoSize[right.a] - kDinoSize[o.a] < 20) return false;
      }
      return true;
    }
    if (p.t == VT.picName) {
      final i = kDinoKeys.indexOf(p.s);
      if (i < 0 || right.t != VT.dino || right.a != i) return false;
      return it.options.every((o) => o.t == VT.dino);
    }
    if (p.t != VT.dino) return false;
    final i = p.a;
    if ((it.tip == 'tip.notdino') != notDino(i)) return false;
    final diet = kDietEmoji.indexOf(right.s);
    if (diet >= 0) return diet == kDinoDiet[i] && it.options.every((o) => kDietEmoji.contains(o.s));
    final home = kHomeIcon.indexOf(right.s);
    if (home >= 0) return home == kDinoHome[i] && it.options.every((o) => kHomeIcon.contains(o.s));
    return false;
  }
}

// ---------------------------------------------------------------- meyve ve sebze

class MeyveSebzeKind extends QuizKind {
  const MeyveSebzeKind();
  @override
  String get id => 'meyve-sebze';

  Vis _item(int i, int d) => Vis(VT.pic, s: kProduce[i].key, c: d >= 5 ? 1 : 0);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = optCount(d);
    final all = List<int>.generate(kProduce.length, (i) => i);
    final types = d <= 1 ? 2 : (d <= 3 ? 3 : 4);
    switch (r.nextInt(types)) {
      case 0: {
        // meyve mi sebze mi? (iki sepet)
        final i = r.nextInt(kProduce.length);
        final fruit = kProduce[i].fruit;
        return qi(_item(i, 0), Vis(VT.pic, s: fruit ? 'g.fruit' : 'g.veg', c: 1), [Vis(VT.pic, s: fruit ? 'g.veg' : 'g.fruit', c: 1)], r);
      }
      case 1: {
        // ad → resim
        final i = r.nextInt(kProduce.length);
        final others = _pickOthers(r, all, n - 1, (x) => x == i);
        return qi(Vis(VT.picName, s: kProduce[i].key), _item(i, 0), [for (final o in others) _item(o, 0)], r);
      }
      case 2: {
        // renk → bu renkteki
        final colored = [for (final i in all) if (kProduce[i].color >= 0) i];
        final i = r.pick(colored);
        final col = kProduce[i].color;
        final others = _pickOthers(r, colored, n - 1, (x) => kProduce[x].color == col);
        if (others.length < n - 1) return null;
        return qi(Vis(VT.color, a: col, c: d >= 5 ? 1 : 0), _item(i, d), [for (final o in others) _item(o, d)], r);
      }
      default: {
        // nerede yetişir?
        final grown = [for (final i in all) if (kProduce[i].grow >= 0) i];
        final i = r.pick(grown);
        final g = kProduce[i].grow;
        return qi(_item(i, d), Vis(VT.grow, a: g), [for (var x = 0; x < 3; x++) if (x != g) Vis(VT.grow, a: x)], r);
      }
    }
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    final right = it.options[it.answer];
    if (p.t == VT.color) {
      final i = produceOf(right.s);
      if (i < 0 || kProduce[i].color != p.a) return false;
      for (var k = 0; k < it.options.length; k++) {
        if (k == it.answer) continue;
        final o = produceOf(it.options[k].s);
        if (o < 0 || kProduce[o].color < 0 || kProduce[o].color == p.a) return false;
      }
      return true;
    }
    if (p.t == VT.picName) {
      if (right.s != p.s) return false;
      return it.options.every((o) => produceOf(o.s) >= 0);
    }
    final i = produceOf(p.s);
    if (p.t != VT.pic || i < 0) return false;
    if (right.t == VT.grow) return kProduce[i].grow >= 0 && right.a == kProduce[i].grow && it.options.every((o) => o.t == VT.grow);
    if (right.s == 'g.fruit' || right.s == 'g.veg') return (right.s == 'g.fruit') == kProduce[i].fruit && it.options.length == 2;
    return false;
  }
}
