import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/names.dart';
import '../kid/quiz.dart';
import '../kid/store.dart';
import '../kid/vis.dart';
import '../studio_chrome.dart';
import 'quizzes.dart';

// ---------------------------------------------------------------- duygular

/// Duygu sırası: 0 mutlu, 1 üzgün, 2 kızgın, 3 korkmuş, 4 şaşkın, 5 sakin.
const List<String> kTipKeys = ['tip.happy', 'tip.sad', 'tip.angry', 'tip.scared', 'tip.surprised', 'tip.calm'];

/// Her duygu için resimli küçük olaylar (okuma bilmeyen çocuklar için yalnız simge).
const List<List<String>> kFeelScenes = [
  ['🎂🎁', '🎈🎉', '🐶🤗', '🏖️🪣', '🍦☀️'],
  ['🎈💨😮‍💨', '🧸💔', '🌧️⚽🚫', '🍦⬇️💥'],
  ['🏰👟💥', '🧩🙅', '✏️✂️💥'],
  ['⛈️⚡', '🌑🔦', '🕷️🕸️', '🐺🌲🌙'],
  ['🎁❓', '🐣🥚', '🎆✨', '🦋👃'],
  ['🌙📖', '🛁🫧', '🌳🍃', '🎨🖌️', '🐟🫧'],
];

/// Birbirine çok yakın, aynı soruda yan yana çıkmaması gereken duygular.
bool feelClash(int a, int b) => _clash(const [0, 4, 3, 4, 0, 5], a, b);

/// Düz [x0, y0, x1, y1, …] listesinde (a, b) ya da (b, a) çifti var mı?
bool _clash(List<int> flat, int a, int b) {
  for (var i = 0; i + 1 < flat.length; i += 2) {
    if ((flat[i] == a && flat[i + 1] == b) || (flat[i] == b && flat[i + 1] == a)) return true;
  }
  return false;
}

class DuyguKind extends QuizKind {
  const DuyguKind();
  @override
  String get id => 'duygular';

  @override
  int optCount(int d) => d <= 2 ? 3 : 4;

  List<int> _others(int e, int n, SeededRandom r) {
    final pool = [for (var i = 0; i < kFeelScenes.length; i++) if (i != e && !feelClash(e, i)) i];
    r.shuffle(pool);
    return pool.take(n).toList();
  }

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final t = d <= 2 ? 0 : (d <= 5 ? r.nextInt(2) : r.nextInt(3));
    final e = r.nextInt(kFeelScenes.length);
    final tone = r.nextInt(kSkinTones.length);
    final others = _others(e, optCount(d) - 1, r);
    if (others.length < optCount(d) - 1) return null;
    final tipVis = Vis(VT.face, a: e, b: tone);
    switch (t) {
      case 0: {
        return qi(Vis(VT.emoji, s: r.pick(kFeelScenes[e])), Vis(VT.face, a: e, b: tone, c: d >= 4 ? 1 : 0),
            [for (final o in others) Vis(VT.face, a: o, b: r.nextInt(kSkinTones.length), c: d >= 4 ? 1 : 0)], r,
            tip: kTipKeys[e], tipVis: tipVis);
      }
      case 1: {
        return qi(Vis(VT.face, a: e, b: tone), Vis(VT.emoji, s: r.pick(kFeelScenes[e])),
            [for (final o in others) Vis(VT.emoji, s: r.pick(kFeelScenes[o]))], r,
            tip: kTipKeys[e], tipVis: tipVis);
      }
      default: {
        return qi(Vis(VT.face, a: e, b: tone), Vis(VT.emoName, a: e), [for (final o in others) Vis(VT.emoName, a: o)], r,
            tip: kTipKeys[e], tipVis: tipVis);
      }
    }
  }

  @override
  bool extra(QItem it) {
    // Doğru seçenek, sorunun duygusuyla aynı olmalı; yanlışlar çakışmamalı.
    final p = it.prompt;
    final right = it.options[it.answer];
    int feelOf(Vis v) {
      if (v.t == VT.face || v.t == VT.emoName) return v.a;
      for (var i = 0; i < kFeelScenes.length; i++) {
        if (kFeelScenes[i].contains(v.s)) return i;
      }
      return -1;
    }

    if (p == null) return false;
    final e = feelOf(p);
    if (e < 0 || feelOf(right) != e) return false;
    for (var i = 0; i < it.options.length; i++) {
      if (i == it.answer) continue;
      final o = feelOf(it.options[i]);
      if (o < 0 || o == e || feelClash(o, e)) return false;
    }
    return it.tip == kTipKeys[e];
  }
}

// ---------------------------------------------------------------- zıt kavramlar

/// Zıt çiftler: (bir yan, öbür yan). Aynı çiftten olmayan resimler çeldiricidir.
const List<(List<String>, List<String>)> kOpposites = [
  (['🐘', '🌳'], ['🐭', '🌱']), // büyük – küçük
  (['🔥', '☕'], ['🧊', '⛄']), // sıcak – soğuk
  (['🐇', '🚀'], ['🐢', '🐌']), // hızlı – yavaş
  (['🔋'], ['🪫']), // dolu – boş
  (['🔓', '📖'], ['🔒', '📕']), // açık – kapalı
  (['🌞', '🏙️'], ['🌜', '🌃']), // gündüz – gece
  (['⬆️'], ['⬇️']), // yukarı – aşağı
  (['🪨', '⚓'], ['🪶', '🫧']), // ağır – hafif
  (['🌧️', '💦'], ['🏜️', '🌵']), // ıslak – kuru
  (['📢', '🥁'], ['🤫', '🔇']), // gürültülü – sessiz
  (['😀'], ['😢']), // mutlu – üzgün
];

/// Anlamca karışabilecek çift grupları (ör. fil hem büyük hem ağır).
bool oppClash(int a, int b) => _clash(const [0, 7, 1, 8, 5, 9, 1, 5], a, b);

int oppPairOf(String s) {
  for (var i = 0; i < kOpposites.length; i++) {
    if (kOpposites[i].$1.contains(s) || kOpposites[i].$2.contains(s)) return i;
  }
  return -1;
}

class ZitKind extends QuizKind {
  const ZitKind();
  @override
  String get id => 'zit-kavramlar';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final pairs = d <= 2 ? 6 : (d <= 5 ? 9 : kOpposites.length);
    final p = r.nextInt(pairs);
    final side = r.nextInt(2);
    final (a, b) = kOpposites[p];
    final mine = side == 0 ? a : b;
    final other = side == 0 ? b : a;
    final prompt = r.pick(mine);
    final right = r.pick(other);
    final pool = [for (var i = 0; i < pairs; i++) if (i != p && !oppClash(i, p)) i];
    r.shuffle(pool);
    final wrong = <String>[];
    for (final q in pool.take(optCount(d) - 1)) {
      final (x, y) = kOpposites[q];
      wrong.add(r.pick(r.chance(0.5) ? x : y));
    }
    if (wrong.length < optCount(d) - 1) return null;
    return qi(Vis(VT.emoji, s: prompt), Vis(VT.emoji, s: right), [for (final w in wrong) Vis(VT.emoji, s: w)], r);
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    final pi = oppPairOf(p.s);
    if (pi < 0) return false;
    final (a, b) = kOpposites[pi];
    final right = it.options[it.answer].s;
    final onA = a.contains(p.s);
    if (!(onA ? b.contains(right) : a.contains(right))) return false;
    for (var i = 0; i < it.options.length; i++) {
      if (i == it.answer) continue;
      final q = oppPairOf(it.options[i].s);
      if (q < 0 || q == pi || oppClash(q, pi)) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- yönler

class YonKind extends QuizKind {
  const YonKind();
  @override
  String get id => 'yonler';

  /// Zorluğa göre kullanılan konumlar: önce üst/alt, sonra sağ/sol, sonra ön/arka/iç.
  int rels(int d) => d <= 1 ? 2 : (d <= 3 ? 4 : (d <= 5 ? 6 : 7));

  @override
  int optCount(int d) => math.min<int>(rels(d), d <= 2 ? 2 : (d <= 4 ? 3 : 4));

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final n = rels(d);
    // üst/alt ilk sırada kolay: 2,3 → 0,1 sağ/sol
    final order = [2, 3, 0, 1, 4, 5, 6];
    final avail = order.take(n).toList();
    final rel = r.pick(avail);
    final obj = r.nextInt(kPlaceMovers.length);
    final others = [for (final x in avail) if (x != rel) x];
    r.shuffle(others);
    final wrong = others.take(optCount(d) - 1).toList();
    final arrow = d <= 4 && rel <= 3 ? 1 : 0;
    return qi(Vis(VT.rel, a: rel, b: obj, c: arrow), Vis(VT.place, a: rel, b: obj), [for (final w in wrong) Vis(VT.place, a: w, b: obj)], r);
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null || p.t != VT.rel) return false;
    final right = it.options[it.answer];
    if (right.t != VT.place || right.a != p.a || right.b != p.b) return false;
    return it.options.every((o) => o.t == VT.place && o.a >= 0 && o.a < kRelKeys.length);
  }
}

// ---------------------------------------------------------------- sağlıklı alışkanlıklar

/// Günlük sıralar (sıra önemli).
const List<List<String>> kRoutines = [
  ['⏰', '🪥', '🧼', '🥣', '🎒'], // sabah: uyan, diş, el, kahvaltı, okul
  ['💧', '🧼', '🫧', '🧻'], // el yıkama: ıslat, sabun, köpürt, kurula
  ['🛁', '🪥', '📖', '😴'], // akşam: banyo, diş, masal, uyku
  ['🧺', '👕', '🧦', '👟'], // giyinme: dolap, tişört, çorap, ayakkabı
];

/// Durum → iyi seçim, daha az iyi seçimler.
const List<(String, String, List<String>)> kChoices = [
  ('🏃💦', '💧', ['🥤', '🍭', '🍟']),
  ('🌙🥱', '🛏️', ['📱', '📺', '🎮']),
  ('🍽️', '🧼', ['🎮', '🧸', '⚽']),
  ('🤧', '🧻', ['🤚', '🍪', '🧸']),
  ('☀️🏖️', '🧢', ['🧤', '🧣', '🧥']),
  ('🍬🦷', '🪥', ['🍫', '📺', '🍭']),
  ('🚴', '⛑️', ['👒', '🎩', '🎀']),
  ('🥶❄️', '🧣', ['🩳', '🍦', '🩴']),
  ('🚽', '🧼', ['📱', '🍪', '🎮']),
  ('📺⏳', '🌳⚽', ['📺', '📱', '🎮']),
];

class SaglikKind extends QuizKind {
  const SaglikKind();
  @override
  String get id => 'saglikli-aliskanliklar';

  @override
  int optCount(int d) => d <= 2 ? 2 : (d <= 5 ? 3 : 4);

  @override
  QItem? item(int d, SeededRandom r, int k) {
    if (r.chance(0.5)) {
      final ri = r.nextInt(d <= 3 ? 3 : kRoutines.length);
      final steps = kRoutines[ri];
      final at = 1 + r.nextInt(steps.length - 1);
      final shown = steps.take(at).join(' ➜ ');
      final right = steps[at];
      final pool = <String>{};
      for (var i = 0; i < steps.length; i++) {
        if (i != at && steps[i] != right) pool.add(steps[i]);
      }
      final ps = pool.toList();
      r.shuffle(ps);
      final wrong = ps.take(optCount(d) - 1).toList();
      if (wrong.length < optCount(d) - 1) return null;
      return qi(Vis(VT.text, s: '$shown ➜ ?'), Vis(VT.emoji, s: right), [for (final w in wrong) Vis(VT.emoji, s: w)], r);
    }
    final c = kChoices[r.nextInt(kChoices.length)];
    final bad = [...c.$3];
    r.shuffle(bad);
    return qi(Vis(VT.emoji, s: c.$1), Vis(VT.emoji, s: c.$2), [for (final b in bad.take(optCount(d) - 1)) Vis(VT.emoji, s: b)], r);
  }

  @override
  bool extra(QItem it) {
    final p = it.prompt;
    if (p == null) return false;
    final right = it.options[it.answer].s;
    if (p.t == VT.text) {
      final shown = p.s.replaceAll(' ➜ ?', '').split(' ➜ ');
      for (final steps in kRoutines) {
        if (steps.length > shown.length && _prefix(steps, shown)) {
          if (steps[shown.length] != right) return false;
          return it.options.every((o) => o.s == right || (steps.contains(o.s) && steps.indexOf(o.s) != shown.length));
        }
      }
      return false;
    }
    for (final c in kChoices) {
      if (c.$1 == p.s) return c.$2 == right && it.options.every((o) => o.s == right || c.$3.contains(o.s));
    }
    return false;
  }

  bool _prefix(List<String> steps, List<String> shown) {
    for (var i = 0; i < shown.length; i++) {
      if (steps[i] != shown[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- geri dönüşüm

/// Kutular: 0 kâğıt, 1 plastik, 2 cam, 3 metal, 4 organik.
const List<List<String>> kWaste = [
  ['📰', '📦', '📄', '✉️', '🗞️'],
  ['🧴', '🥤', '🪣'],
  ['🫙', '🥛'],
  ['🥫', '🔩', '📎', '🔧'],
  ['🍌', '🍎', '🥕', '🍂', '🥚', '🍞'],
];
const List<Color> kBinColors = [Color(0xFF3A86C8), Color(0xFFF2C14E), Color(0xFF5BAA6E), Color(0xFF8D99AE), Color(0xFF8D6748)];
const List<String> kBinIcons = ['📄', '🧴', '🫙', '🥫', '🍂'];

int wasteBin(String e) {
  for (var i = 0; i < kWaste.length; i++) {
    if (kWaste[i].contains(e)) return i;
  }
  return -1;
}

class SortPuzzle extends EPuzzle {
  final List<int> bins;
  final List<String> items;
  const SortPuzzle(this.bins, this.items);
}

class GeriDonusumKind extends EgiticiKind {
  const GeriDonusumKind();
  @override
  String get id => 'geri-donusum';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final bins = d <= 2 ? [0, 1, 4] : (d <= 5 ? [0, 1, 3, 4] : [0, 1, 2, 3, 4]);
    final n = math.min<int>(5 + d, 14);
    final items = <String>[];
    // her kutudan en az bir atık
    for (final b in bins) {
      items.add(r.pick(kWaste[b]));
    }
    while (items.length < n) {
      items.add(r.pick(kWaste[r.pick(bins)]));
    }
    r.shuffle(items);
    return SortPuzzle(bins, items);
  }

  @override
  bool check(EPuzzle p) {
    if (p is! SortPuzzle || p.items.isEmpty || p.bins.length < 2) return false;
    if (p.bins.toSet().length != p.bins.length) return false;
    for (final b in p.bins) {
      if (!p.items.any((e) => wasteBin(e) == b)) return false;
    }
    return p.items.every((e) => p.bins.contains(wasteBin(e)));
  }

  @override
  Widget build(EPlay play) => _SortView(play: play, p: play.puzzle as SortPuzzle);
}

class _SortView extends StatefulWidget {
  final EPlay play;
  final SortPuzzle p;
  const _SortView({required this.play, required this.p});

  @override
  State<_SortView> createState() => _SortViewState();
}

class _SortViewState extends State<_SortView> with Clock<_SortView> {
  int idx = 0;
  int mistakes = 0;
  int? wrongBin;
  int? okBin;
  late int skill;

  EPlay get play => widget.play;
  SortPuzzle get p => widget.p;

  @override
  void initState() {
    super.initState();
    skill = KidStore.instance.skill(play.gameId);
    startClock();
  }

  void _drop(int bin) {
    if (ended || okBin != null || idx >= p.items.length) return;
    final item = p.items[idx];
    if (wasteBin(item) == bin) {
      play.sfx(Sfx.clear);
      play.answer(true);
      setState(() {
        okBin = bin;
        wrongBin = null;
      });
      later(420, () {
        if (idx + 1 >= p.items.length) {
          ended = true;
          if (mistakes == 0) {
            KidStore.instance.setSkill(play.gameId, skill + 1);
          } else if (mistakes * 2 >= p.items.length) {
            KidStore.instance.setSkill(play.gameId, skill - 1);
          }
          setState(() {
            idx++;
            okBin = null;
          });
          play.finish(mistakes: mistakes, seconds: seconds);
          return;
        }
        setState(() {
          idx++;
          okBin = null;
        });
      });
    } else {
      play.sfx(Sfx.error);
      play.answer(false);
      setState(() {
        mistakes++;
        wrongBin = bin;
      });
      later(500, () {
        if (wrongBin == bin) setState(() => wrongBin = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 700.0;
      final townH = clampD(h * 0.24, 80, 220);
      final binW = (w - 16) / p.bins.length - 8;
      final binH = clampD(math.min(h * 0.26, binW * 1.5), 72, 200);
      final itemS = clampD(math.min(w * 0.42, h - townH - binH - 70), 64, 200);
      final done = clampI(idx, 0, p.items.length);
      final current = idx < p.items.length ? p.items[idx] : null;
      return Column(children: [
        SizedBox(
          height: townH,
          width: w,
          child: CustomPaint(painter: _TownPainter(done / p.items.length, done)),
        ),
        Padding(padding: const EdgeInsets.only(top: 6), child: StepDots(done: done, total: p.items.length)),
        Expanded(
          child: Center(
            child: current == null
                ? const SizedBox()
                : Draggable<int>(
                    key: ValueKey('w$idx'),
                    data: idx,
                    feedback: Material(color: Colors.transparent, child: Text(current, style: TextStyle(fontSize: itemS * 0.6))),
                    childWhenDragging: Opacity(opacity: 0.25, child: _ItemCard(e: current, size: itemS)),
                    child: _ItemCard(e: current, size: itemS),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Row(children: [
            for (final b in p.bins)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DragTarget<int>(
                    onAcceptWithDetails: (_) => _drop(b),
                    builder: (context, cand, rej) => _BinTile(
                      bin: b,
                      height: binH,
                      lang: play.lang,
                      hot: cand.isNotEmpty,
                      ok: okBin == b,
                      bad: wrongBin == b,
                      onTap: () => _drop(b),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }
}

class _ItemCard extends StatelessWidget {
  final String e;
  final double size;
  const _ItemCard({required this.e, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: KColors.line, width: 2)),
      child: Center(child: FittedBox(child: Padding(padding: const EdgeInsets.all(8), child: Text(e, style: TextStyle(fontSize: size * 0.55))))),
    );
  }
}

class _BinTile extends StatelessWidget {
  final int bin;
  final double height;
  final String lang;
  final bool hot;
  final bool ok;
  final bool bad;
  final VoidCallback onTap;
  const _BinTile({required this.bin, required this.height, required this.lang, required this.hot, required this.ok, required this.bad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = kBinColors[bin];
    final look = StudioLook.of(context);
    final bg = ok ? const Color(0xFFCDEBD3) : (bad ? const Color(0xFFF1E3DF) : Color.lerp(look.card, col, hot ? 0.75 : 0.5)!);
    final fg = bg.computeLuminance() > 0.35 ? KColors.ink : Colors.white;
    final tile = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: hot ? look.accent : Colors.white24, width: hot ? 2 : 1),
      ),
      elevation: hot ? 4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(children: [
            Container(height: 10, margin: const EdgeInsets.fromLTRB(10, 8, 10, 0), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(5))),
            Expanded(child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: Text(kBinIcons[bin], style: const TextStyle(fontSize: 40))))),
            SizedBox(
              height: height * 0.24,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(nm(kBinKeys[bin], lang), style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 18)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    if (!bad) return tile;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (context, t, ch) => Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 6 * (1 - t), 0), child: ch),
      child: tile,
    );
  }
}

/// Kasaba: doğru ayrılan her atıkla zemin yeşerir, ağaç ve çiçek çıkar.
class _TownPainter extends CustomPainter {
  final double t;
  final int plants;
  _TownPainter(this.t, this.plants);

  @override
  void paint(Canvas c, Size s) {
    final sky = Color.lerp(const Color(0xFFD9D4CC), const Color(0xFFBFE3F5), t)!;
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(18)), fill(sky));
    final gy = s.height * 0.72;
    final grass = Color.lerp(const Color(0xFFB9B2A4), const Color(0xFF8CCB7E), t)!;
    c.drawRect(Rect.fromLTWH(0, gy, s.width, s.height - gy), fill(grass));
    // evler
    final hw = s.width / 7;
    for (var i = 0; i < 3; i++) {
      final x = s.width * (0.12 + i * 0.32);
      final hh = s.height * (0.32 + (i % 2) * 0.08);
      c.drawRect(Rect.fromLTWH(x, gy - hh, hw, hh), fill(const Color(0xFFF3E9DC)));
      final roof = Path()
        ..moveTo(x - 6, gy - hh)
        ..lineTo(x + hw / 2, gy - hh - s.height * 0.14)
        ..lineTo(x + hw + 6, gy - hh)
        ..close();
      c.drawPath(roof, fill(const Color(0xFFE07A5F)));
      c.drawRect(Rect.fromLTWH(x + hw * 0.35, gy - hh * 0.45, hw * 0.3, hh * 0.45), fill(const Color(0xFF8D6748)));
    }
    if (t > 0) {
      c.drawCircle(Offset(s.width * 0.9, s.height * 0.18), s.height * 0.1 * (0.5 + t / 2), fill(const Color(0xFFF6C85F)));
    }
    // bitkiler
    for (var k = 0; k < plants; k++) {
      final x = s.width * ((k * 0.137 + 0.05) % 0.96) + 6;
      final y = gy + (s.height - gy) * (0.3 + (k % 3) * 0.2);
      if (k.isEven) {
        c.drawRect(Rect.fromLTWH(x - 2, y - s.height * 0.12, 4, s.height * 0.12), fill(const Color(0xFF8D6748)));
        c.drawCircle(Offset(x, y - s.height * 0.15), s.height * 0.07, fill(const Color(0xFF4C956C)));
      } else {
        c.drawLine(Offset(x, y), Offset(x, y - s.height * 0.07), stroke(const Color(0xFF4C956C), 2));
        c.drawCircle(Offset(x, y - s.height * 0.08), s.height * 0.025, fill(const [Color(0xFFF28DB2), Color(0xFFF6C85F), Color(0xFFB8A1D9)][k % 3]));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TownPainter old) => old.t != t || old.plants != plants;
}
