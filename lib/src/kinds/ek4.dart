import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../kid/read_aloud.dart';
import '../texts.dart';
import 'write.dart';

// 4. tur: Oyuncak Ev Dünyası, Minik Veteriner, Masal Kitaplığı,
// Araba Yıkama ve Tamir, Dünya Alfabeleri. Kaybetmek yok; yıldız hatalara göre.

// ================================================================ Oyuncak Ev Dünyası

/// Sahneler: (anahtar, zemin rengi, yerler, eşyalar). Yer ve eşyalar emoji.
const List<(String, int, List<String>, List<String>)> kToyScenes = [
  ('oeHome', 0xFFF7E3C9, ['🛏️', '🍽️', '🛁', '🛋️', '📚', '🧺'], ['🧸', '🍎', '🧼', '📕', '☕', '⚽', '🐱', '🧦']),
  ('oeSchool', 0xFFDDEBF7, ['🪑', '🎒', '🗄️', '🖍️', '🧑‍🏫', '📋'], ['✏️', '📒', '🍏', '📐', '🧃', '🎨', '🔤', '🧮']),
  ('oeMarket', 0xFFE6F2DA, ['🛒', '🧺', '🏷️', '🧾', '🥫', '🧑‍🌾'], ['🥕', '🍞', '🥚', '🧀', '🍌', '🥛', '🍅', '🍪']),
  ('oePark', 0xFFD8F0D2, ['🌳', '🪁', '🛝', '🪣', '⛲', '🪨'], ['🐶', '🦆', '🎈', '🏐', '🪀', '🌼', '🍦', '🐿️']),
];

class ToyPuzzle extends EPuzzle {
  final int scene;

  /// Görevler: (eşya, yer).
  final List<(int, int)> tasks;
  const ToyPuzzle(this.scene, this.tasks);
}

class OyuncakEvKind extends EgiticiKind {
  const OyuncakEvKind();
  @override
  String get id => 'oyuncak-ev';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final scene = r.nextInt(kToyScenes.length);
    final n = 3 + math.min<int>(3, d ~/ 3);
    final items = [for (var i = 0; i < kToyScenes[scene].$4.length; i++) i];
    r.shuffle(items);
    final tasks = <(int, int)>[for (var k = 0; k < n; k++) (items[k], r.nextInt(kToyScenes[scene].$3.length))];
    return ToyPuzzle(scene, tasks);
  }

  @override
  bool check(EPuzzle p) =>
      p is ToyPuzzle &&
      p.scene >= 0 &&
      p.scene < kToyScenes.length &&
      p.tasks.length >= 3 &&
      p.tasks.map((t) => t.$1).toSet().length == p.tasks.length &&
      p.tasks.every((t) => t.$1 < kToyScenes[p.scene].$4.length && t.$2 < kToyScenes[p.scene].$3.length);

  @override
  Widget build(EPlay play) => _ToyView(play: play, p: play.puzzle as ToyPuzzle);
}

class _ToyView extends StatefulWidget {
  final EPlay play;
  final ToyPuzzle p;
  const _ToyView({required this.play, required this.p});
  @override
  State<_ToyView> createState() => _ToyViewState();
}

class _ToyViewState extends State<_ToyView> with Clock<_ToyView> {
  int task = 0, mistakes = 0;
  int held = -1;

  /// Serbest oyun: eşya -> yer (yerleştirilen her şey sahnede kalır).
  final Map<int, int> placed = {};

  (String, int, List<String>, List<String>) get sc => kToyScenes[widget.p.scene];

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _spot(int s) {
    if (held < 0 || ended) return;
    final t = widget.p.tasks[math.min(task, widget.p.tasks.length - 1)];
    setState(() => placed[held] = s);
    if (task < widget.p.tasks.length && held == t.$1 && s == t.$2) {
      widget.play.sfx(Sfx.clear);
      widget.play.answer(true);
      setState(() {
        task++;
        held = -1;
      });
      if (task >= widget.p.tasks.length) {
        ended = true;
        later(700, () => widget.play.finish(mistakes: mistakes, seconds: seconds));
      }
    } else {
      // Serbest oyunda yanlış yoktur; görevdeki eşya başka yere konduysa nazik uyarı.
      if (held == t.$1) {
        mistakes++;
        widget.play.answer(false);
        widget.play.sfx(Sfx.error);
      } else {
        widget.play.sfx(Sfx.place);
      }
      setState(() => held = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final p = widget.p;
    final cur = task < p.tasks.length ? p.tasks[task] : null;
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: task, total: p.tasks.length)),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: KColors.paper, borderRadius: BorderRadius.circular(18)),
        // Dar ekranda / uzun dilde taşmasın: satır sığacak kadar küçülür.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${et(lang, 'oeTask')}: ', style: const TextStyle(color: KColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(cur == null ? '🎉' : '${sc.$4[cur.$1]}  ➜  ${sc.$3[cur.$2]}', style: const TextStyle(fontSize: 30, color: KColors.ink)),
          ]),
        ),
      ),
      Text(et(lang, sc.$1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(sc.$2), borderRadius: BorderRadius.circular(24)),
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(10),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var s = 0; s < sc.$3.length; s++)
                Material(
                  color: Colors.white.withValues(alpha: held >= 0 ? 0.95 : 0.75),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _spot(s),
                    child: Stack(alignment: Alignment.center, children: [
                      Text(sc.$3[s], style: const TextStyle(fontSize: 40)),
                      Positioned(
                        bottom: 4,
                        child: Text([for (final e in placed.entries) if (e.value == s) sc.$4[e.key]].join(),
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
      SizedBox(
        height: 84,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (var i = 0; i < sc.$4.length; i++)
            Padding(
              padding: const EdgeInsets.all(6),
              child: BigButton(
                size: 64,
                color: held == i ? KColors.sun : null,
                onTap: ended ? null : () => setState(() => held = held == i ? -1 : i),
                child: Text(sc.$4[i], style: const TextStyle(fontSize: 30)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ================================================================ Minik Veteriner

/// Hayvanlar: (emoji, sevdiği yiyecek).
const List<(String, String)> kVetAnimals = [
  ('🐶', '🦴'), ('🐱', '🐟'), ('🐰', '🥕'), ('🐢', '🥬'), ('🦜', '🌻'), ('🐴', '🍎'), ('🐹', '🌽'), ('🐑', '🌾'),
];

/// Bakım aletleri: 0 yıka, 1 tara, 2 besle, 3 su ver, 4 bant, 5 dinle, 6 sarıl.
const List<String> kVetTools = ['🫧', '🪮', '🍽️', '💧', '🩹', '🩺', '🤗'];
const List<String> kVetToolKeys = ['vtWash', 'vtBrush', 'vtFeed', 'vtWater', 'vtBandage', 'vtListen', 'vtCuddle'];

class VetPuzzle extends EPuzzle {
  /// Hastalar: (hayvan, ihtiyaç sırası).
  final List<(int, List<int>)> patients;
  const VetPuzzle(this.patients);
}

class VeterinerKind extends EgiticiKind {
  const VeterinerKind();
  @override
  String get id => 'veteriner';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final n = 2 + math.min<int>(2, d ~/ 4);
    final pats = <(int, List<int>)>[];
    final used = <int>{};
    for (var i = 0; i < n; i++) {
      var a = r.nextInt(kVetAnimals.length);
      for (var g = 0; g < 10 && used.contains(a); g++) {
        a = r.nextInt(kVetAnimals.length);
      }
      used.add(a);
      final pool = [0, 1, 2, 3, 4, 5];
      r.shuffle(pool);
      final k = 2 + math.min<int>(3, d ~/ 3);
      pats.add((a, [...pool.take(k), 6]));
    }
    return VetPuzzle(pats);
  }

  @override
  bool check(EPuzzle p) =>
      p is VetPuzzle &&
      p.patients.length >= 2 &&
      p.patients.every((x) => x.$1 < kVetAnimals.length && x.$2.length >= 3 && x.$2.toSet().length == x.$2.length && x.$2.last == 6);

  @override
  Widget build(EPlay play) => _VetView(play: play, p: play.puzzle as VetPuzzle);
}

class _VetView extends StatefulWidget {
  final EPlay play;
  final VetPuzzle p;
  const _VetView({required this.play, required this.p});
  @override
  State<_VetView> createState() => _VetViewState();
}

class _VetViewState extends State<_VetView> with Clock<_VetView> {
  int pat = 0, step = 0, mistakes = 0;
  String fx = '';

  @override
  void initState() {
    super.initState();
    startClock();
    later(500, _sayNext);
  }

  /// Sıradaki aletin adı okunur (okuma bilmeyen çocuk için).
  void _sayNext() {
    if (ended) return;
    final need = widget.p.patients[pat].$2;
    if (step < need.length) widget.play.say(et(widget.play.lang, kVetToolKeys[need[step]]));
  }

  @override
  void dispose() {
    widget.play.hush();
    super.dispose();
  }

  void _tool(int t) {
    if (ended) return;
    final need = widget.p.patients[pat].$2;
    if (need[step] == t) {
      widget.play.sfx(t == 6 ? Sfx.combo : Sfx.clear);
      widget.play.answer(true);
      setState(() {
        fx = t == 2 ? kVetAnimals[widget.p.patients[pat].$1].$2 : kVetTools[t];
        step++;
      });
      if (step < need.length) later(450, _sayNext);
      if (step >= need.length) {
        later(800, () {
          if (pat + 1 >= widget.p.patients.length) {
            ended = true;
            widget.play.finish(mistakes: mistakes, seconds: seconds);
          } else {
            setState(() {
              pat++;
              step = 0;
              fx = '';
            });
            later(400, _sayNext);
          }
        });
      }
    } else {
      mistakes++;
      widget.play.answer(false);
      widget.play.sfx(Sfx.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final (a, need) = widget.p.patients[pat];
    final next = step < need.length ? need[step] : -1;
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: pat, total: widget.p.patients.length)),
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE8F4F1), borderRadius: BorderRadius.circular(26)),
          child: Stack(alignment: Alignment.center, children: [
            Text(kVetAnimals[a].$1, style: const TextStyle(fontSize: 120)),
            if (fx.isNotEmpty) Positioned(top: 18, right: 28, child: Text(fx, style: const TextStyle(fontSize: 44))),
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Text(next < 0 ? '💖' : '${kVetTools[next]}  ${et(lang, kVetToolKeys[next])}',
                    style: const TextStyle(fontSize: 20, color: KColors.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var t = 0; t < kVetTools.length; t++)
          BigButton(
            size: 62,
            tooltip: et(lang, kVetToolKeys[t]),
            onTap: ended ? null : () => _tool(t),
            child: Text(kVetTools[t], style: const TextStyle(fontSize: 28)),
          ),
      ]),
      const SizedBox(height: 14),
    ]);
  }
}

// ================================================================ Masal Kitaplığı

/// Masallar (Ezop, kamu malı; kısa özgün anlatım): başlık + 4 sayfa; her
/// sayfanın resmi emojilerle kurulur.
const List<(String, List<String>, List<String>)> kTales = [
  ('mt0', ['mt0a', 'mt0b', 'mt0c', 'mt0d'], ['🐢🐇', '🐇💨🌳', '🐇😴 🐢🚶', '🐢🏁🎉']),
  ('mt1', ['mt1a', 'mt1b', 'mt1c', 'mt1d'], ['🦁😴🐭', '🦁✋🐭', '🦁🕸️', '🐭✂️🕸️🦁']),
  ('mt2', ['mt2a', 'mt2b', 'mt2c', 'mt2d'], ['🐜🌾☀️', '🦗🎻☀️', '❄️🦗😢', '🐜🍞🦗🤝']),
  ('mt3', ['mt3a', 'mt3b', 'mt3c', 'mt3d'], ['🐦🏺💧', '🐦🤔', '🐦🪨🏺', '🐦💧😊']),
];

class TalePuzzle extends EPuzzle {
  final int tale;

  /// Sıralama oyunu: karışık sayfa sırası.
  final List<int> order;
  const TalePuzzle(this.tale, this.order);
}

class MasalKind extends EgiticiKind {
  const MasalKind();
  @override
  String get id => 'masal';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final tale = r.nextInt(kTales.length);
    final order = [0, 1, 2, 3];
    for (var g = 0; g < 10; g++) {
      r.shuffle(order);
      if (order[0] != 0 || order[1] != 1) break;
    }
    return TalePuzzle(tale, order);
  }

  @override
  bool check(EPuzzle p) =>
      p is TalePuzzle && p.tale >= 0 && p.tale < kTales.length && (p.order.toList()..sort()).join() == '0123' && p.order.join() != '0123';

  @override
  Widget build(EPlay play) => _TaleView(play: play, p: play.puzzle as TalePuzzle);
}

class _TaleView extends StatefulWidget {
  final EPlay play;
  final TalePuzzle p;
  const _TaleView({required this.play, required this.p});
  @override
  State<_TaleView> createState() => _TaleViewState();
}

class _TaleViewState extends State<_TaleView> with Clock<_TaleView> {
  int page = 0, mistakes = 0;
  int word = -1;
  Timer? reader;
  final List<int> picked = [];

  (String, List<String>, List<String>) get tale => kTales[widget.p.tale];
  bool get quiz => page >= 4;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  void dispose() {
    reader?.cancel();
    if (speaking) ReadAloud.instance.stop();
    super.dispose();
  }

  /// Sesli okuma: cihazın çevrimdışı sistem sesi metni okur, okunan sözcük
  /// vurgulanır. Bu dilde ses yoksa (ya da web/test) "birlikte oku":
  /// sözcükler sırayla vurgulanır.
  bool speaking = false;

  /// null: henüz bilinmiyor; false: bu dilde çevrimdışı ses yok.
  bool? hasVoice;

  void _stopReading() {
    _gen++;
    reader?.cancel();
    if (speaking) ReadAloud.instance.stop();
    speaking = false;
  }

  int _gen = 0;

  Future<void> _readAlong() async {
    _stopReading();
    final my = ++_gen;
    final lang = widget.play.lang;
    final text = et(lang, tale.$2[page]);
    final pg = page;
    setState(() => word = 0);
    if (hasVoice != false) {
      speaking = true;
      final ok = await ReadAloud.instance.speak(text, lang, onWord: (i) {
        if (mounted && page == pg && speaking) setState(() => word = i);
      }, onDone: () {
        if (mounted && page == pg) {
          setState(() {
            speaking = false;
            word = -1;
          });
        }
      });
      if (!mounted || my != _gen) return;
      if (ok) {
        if (hasVoice != true) setState(() => hasVoice = true);
        return;
      }
      speaking = false;
      if (page != pg) return;
      setState(() => hasVoice = false);
    }
    _highlightOnly(text.split(' ').length);
  }

  void _highlightOnly(int n) {
    reader?.cancel();
    setState(() => word = 0);
    reader = Timer.periodic(const Duration(milliseconds: 520), (t) {
      if (!mounted) return;
      setState(() => word++);
      if (word >= n) {
        t.cancel();
        setState(() => word = -1);
      }
    });
  }

  void _pick(int pg) {
    if (ended || picked.contains(pg)) return;
    if (pg == picked.length) {
      widget.play.sfx(Sfx.clear);
      widget.play.answer(true);
      setState(() => picked.add(pg));
      if (picked.length == 4) {
        ended = true;
        later(700, () => widget.play.finish(mistakes: mistakes, seconds: seconds));
      }
    } else {
      mistakes++;
      widget.play.answer(false);
      widget.play.sfx(Sfx.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    if (quiz) {
      return Column(children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: picked.length, total: 4)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(et(lang, 'mkOrder'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(12), mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
            for (final pg in widget.p.order)
              Material(
                color: picked.contains(pg) ? const Color(0xFFD7EEDC) : KColors.paper,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _pick(pg),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      FittedBox(child: Text(tale.$3[pg], style: const TextStyle(fontSize: 44))),
                      if (picked.contains(pg))
                        Text('${picked.indexOf(pg) + 1}', style: const TextStyle(fontSize: 22, color: KColors.ink, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]);
    }
    final words = et(lang, tale.$2[page]).split(' ');
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: page, total: 4)),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(et(lang, tale.$1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: KColors.paper, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Expanded(child: FittedBox(child: Text(tale.$3[page], style: const TextStyle(fontSize: 70)))),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
              for (var i = 0; i < words.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: i == word ? KColors.sun : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                  child: Text(words[i], style: const TextStyle(fontSize: 22, color: KColors.ink, fontWeight: FontWeight.w700)),
                ),
            ]),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          BigButton(
            tooltip: et(lang, 'mkRead'),
            onTap: _readAlong,
            child: Icon(hasVoice == false ? Icons.record_voice_over : Icons.volume_up_rounded, size: 30),
          ),
          const SizedBox(width: 24),
          BigButton(
            tooltip: et(lang, 'mkNext'),
            onTap: () {
              _stopReading();
              widget.play.sfx(Sfx.tap);
              setState(() {
                page++;
                word = -1;
              });
            },
            child: const Icon(Icons.arrow_forward, size: 34),
          ),
        ]),
      ),
    ]);
  }
}

// ================================================================ Araba Yıkama ve Tamir

/// Araçlar: emoji. Aletler: 0 sünger, 1 su, 2 anahtar, 3 tekerlek, 4 çekiç, 5 boya.
const List<String> kCars = ['🚗', '🚙', '🚌', '🚜', '🚚', '🏎️', '🚒', '🚑'];
const List<String> kCarTools = ['🧽', '🚿', '🔧', '🛞', '🔨', '🖌️'];
const List<String> kCarToolKeys = ['atSponge', 'atRinse', 'atWrench', 'atTire', 'atHammer', 'atPaint'];
const List<int> kCarPaints = [0xFFE4572E, 0xFF3F6FD8, 0xFF2F8F6B, 0xFFF2A516, 0xFF8E44AD];

class CarPuzzle extends EPuzzle {
  final int car;

  /// İşler sırasıyla: aletler (5 = boya, [paint] rengiyle).
  final List<int> jobs;
  final int paint;
  const CarPuzzle(this.car, this.jobs, this.paint);
}

class ArabaTamirKind extends EgiticiKind {
  const ArabaTamirKind();
  @override
  String get id => 'araba-tamir';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final jobs = <int>[0, 1];
    if (d >= 2 || r.chance(0.5)) jobs.addAll([3, 2]);
    if (d >= 4 && r.chance(0.6)) jobs.add(4);
    if (d >= 3 || r.chance(0.5)) jobs.add(5);
    if (d >= 6) jobs.insert(0, 1);
    return CarPuzzle(r.nextInt(kCars.length), jobs, r.nextInt(kCarPaints.length));
  }

  @override
  bool check(EPuzzle p) =>
      p is CarPuzzle && p.car < kCars.length && p.jobs.length >= 2 && p.jobs.every((j) => j >= 0 && j < kCarTools.length) && p.paint < kCarPaints.length;

  @override
  Widget build(EPlay play) => _CarView(play: play, p: play.puzzle as CarPuzzle);
}

class _CarView extends StatefulWidget {
  final EPlay play;
  final CarPuzzle p;
  const _CarView({required this.play, required this.p});
  @override
  State<_CarView> createState() => _CarViewState();
}

class _CarViewState extends State<_CarView> with Clock<_CarView> {
  int step = 0, mistakes = 0;
  int color = -1;
  int scrub = 0;

  @override
  void initState() {
    super.initState();
    startClock();
    later(500, _sayNext);
  }

  /// Sıradaki işin aletinin adı okunur (okuma bilmeyen çocuk için).
  void _sayNext() {
    if (ended) return;
    final jobs = widget.p.jobs;
    if (step < jobs.length) widget.play.say(et(widget.play.lang, kCarToolKeys[jobs[step]]));
  }

  @override
  void dispose() {
    widget.play.hush();
    super.dispose();
  }

  void _tool(int t, {int paint = -1}) {
    if (ended) return;
    final p = widget.p;
    final want = p.jobs[step];
    final ok = t == want && (t != 5 || paint == p.paint);
    if (!ok) {
      mistakes++;
      widget.play.answer(false);
      widget.play.sfx(Sfx.error);
      return;
    }
    // Süngerle üç kez ovalanır (ASMR hissi), diğerleri tek dokunuş.
    if (t == 0 && scrub < 2) {
      setState(() => scrub++);
      widget.play.sfx(Sfx.tap);
      return;
    }
    widget.play.sfx(Sfx.clear);
    widget.play.answer(true);
    setState(() {
      if (t == 5) color = paint;
      step++;
      scrub = 0;
    });
    if (step < p.jobs.length) later(450, _sayNext);
    if (step >= p.jobs.length) {
      ended = true;
      later(700, () => widget.play.finish(mistakes: mistakes, seconds: seconds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final p = widget.p;
    final want = step < p.jobs.length ? p.jobs[step] : -1;
    final dirty = !p.jobs.sublist(0, step).contains(1);
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: step, total: p.jobs.length)),
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color >= 0 ? Color(kCarPaints[color]).withValues(alpha: 0.35) : const Color(0xFFE6EEF5),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Stack(alignment: Alignment.center, children: [
            // Araç resmi: kısa ekranda alana sığacak kadar küçülür, yazı ölçeğiyle büyümez.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(kCars[p.car], style: const TextStyle(fontSize: 120), textScaler: TextScaler.noScaling),
                ),
              ),
            ),
            if (dirty) const Positioned(top: 30, left: 40, child: Text('🟤 🟤', style: TextStyle(fontSize: 26))),
            if (scrub > 0) Positioned(top: 20, right: 40, child: Text('🫧' * scrub, style: const TextStyle(fontSize: 30))),
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(want < 0 ? '✨' : '${kCarTools[want]}  ${et(lang, kCarToolKeys[want])}',
                      style: const TextStyle(fontSize: 20, color: KColors.ink, fontWeight: FontWeight.w700)),
                  if (want == 5) ...[
                    const SizedBox(width: 8),
                    Container(width: 26, height: 26, decoration: BoxDecoration(color: Color(kCarPaints[p.paint]), shape: BoxShape.circle)),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var t = 0; t < 5; t++)
          BigButton(
            size: 60,
            tooltip: et(lang, kCarToolKeys[t]),
            onTap: ended ? null : () => _tool(t),
            child: Text(kCarTools[t], style: const TextStyle(fontSize: 28)),
          ),
      ]),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
        for (var c = 0; c < kCarPaints.length; c++)
          BigButton(
            size: 48,
            color: Color(kCarPaints[c]),
            tooltip: et(lang, 'atPaint'),
            onTap: ended ? null : () => _tool(5, paint: c),
            child: const Icon(Icons.brush, size: 20),
          ),
      ]),
      const SizedBox(height: 14),
    ]);
  }
}

// ================================================================ Dünya Alfabeleri

/// Yazılar: (ad anahtarı, [harf, okunuş] çiftleri). Yalnız alfabe; dinî içerik yok.
const List<(String, List<(String, String)>)> kScripts = [
  ('daArabic', [
    ('ا', 'a'), ('ب', 'b'), ('ت', 't'), ('ث', 'th'), ('ج', 'j'), ('ح', 'ḥ'), ('خ', 'kh'), ('د', 'd'), ('ذ', 'dh'), ('ر', 'r'),
    ('ز', 'z'), ('س', 's'), ('ش', 'sh'), ('ص', 'ṣ'), ('ض', 'ḍ'), ('ط', 'ṭ'), ('ظ', 'ẓ'), ('ع', 'ʿ'), ('غ', 'gh'), ('ف', 'f'),
    ('ق', 'q'), ('ك', 'k'), ('ل', 'l'), ('م', 'm'), ('ن', 'n'), ('ه', 'h'), ('و', 'w'), ('ي', 'y'),
  ]),
  ('daDevanagari', [
    ('अ', 'a'), ('आ', 'ā'), ('इ', 'i'), ('ई', 'ī'), ('उ', 'u'), ('ऊ', 'ū'), ('ए', 'e'), ('ऐ', 'ai'), ('ओ', 'o'), ('औ', 'au'),
    ('क', 'ka'), ('ख', 'kha'), ('ग', 'ga'), ('घ', 'gha'), ('च', 'ca'), ('छ', 'cha'), ('ज', 'ja'), ('झ', 'jha'), ('ट', 'ṭa'), ('ठ', 'ṭha'),
    ('ड', 'ḍa'), ('ढ', 'ḍha'), ('ण', 'ṇa'), ('त', 'ta'), ('थ', 'tha'), ('द', 'da'), ('ध', 'dha'), ('न', 'na'), ('प', 'pa'), ('फ', 'pha'),
    ('ब', 'ba'), ('भ', 'bha'), ('म', 'ma'), ('य', 'ya'), ('र', 'ra'), ('ल', 'la'), ('व', 'va'), ('श', 'śa'), ('ष', 'ṣa'), ('स', 'sa'),
    ('ह', 'ha'),
  ]),
  ('daHangul', [
    ('ㄱ', 'g/k'), ('ㄴ', 'n'), ('ㄷ', 'd/t'), ('ㄹ', 'r/l'), ('ㅁ', 'm'), ('ㅂ', 'b/p'), ('ㅅ', 's'), ('ㅇ', 'ng'), ('ㅈ', 'j'), ('ㅊ', 'ch'),
    ('ㅋ', 'k'), ('ㅌ', 't'), ('ㅍ', 'p'), ('ㅎ', 'h'), ('ㅏ', 'a'), ('ㅑ', 'ya'), ('ㅓ', 'eo'), ('ㅕ', 'yeo'), ('ㅗ', 'o'), ('ㅛ', 'yo'),
    ('ㅜ', 'u'), ('ㅠ', 'yu'), ('ㅡ', 'eu'), ('ㅣ', 'i'),
  ]),
  ('daKana', [
    ('あ', 'a'), ('い', 'i'), ('う', 'u'), ('え', 'e'), ('お', 'o'), ('か', 'ka'), ('き', 'ki'), ('く', 'ku'), ('け', 'ke'), ('こ', 'ko'),
    ('さ', 'sa'), ('し', 'shi'), ('す', 'su'), ('せ', 'se'), ('そ', 'so'), ('た', 'ta'), ('ち', 'chi'), ('つ', 'tsu'), ('て', 'te'), ('と', 'to'),
    ('な', 'na'), ('に', 'ni'), ('ぬ', 'nu'), ('ね', 'ne'), ('の', 'no'), ('は', 'ha'), ('ひ', 'hi'), ('ふ', 'fu'), ('へ', 'he'), ('ほ', 'ho'),
    ('ま', 'ma'), ('み', 'mi'), ('む', 'mu'), ('め', 'me'), ('も', 'mo'), ('や', 'ya'), ('ゆ', 'yu'), ('よ', 'yo'), ('ら', 'ra'), ('り', 'ri'),
    ('る', 'ru'), ('れ', 're'), ('ろ', 'ro'), ('わ', 'wa'), ('を', 'wo'), ('ん', 'n'),
  ]),
  ('daCyrillic', [
    ('А', 'a'), ('Б', 'b'), ('В', 'v'), ('Г', 'g'), ('Д', 'd'), ('Е', 'e'), ('Ё', 'yo'), ('Ж', 'zh'), ('З', 'z'), ('И', 'i'),
    ('Й', 'y'), ('К', 'k'), ('Л', 'l'), ('М', 'm'), ('Н', 'n'), ('О', 'o'), ('П', 'p'), ('Р', 'r'), ('С', 's'), ('Т', 't'),
    ('У', 'u'), ('Ф', 'f'), ('Х', 'kh'), ('Ц', 'ts'), ('Ч', 'ch'), ('Ш', 'sh'), ('Щ', 'shch'), ('Ы', 'y'), ('Э', 'e'), ('Ю', 'yu'),
    ('Я', 'ya'),
  ]),
  ('daGreek', [
    ('Α', 'a'), ('Β', 'v'), ('Γ', 'g'), ('Δ', 'd'), ('Ε', 'e'), ('Ζ', 'z'), ('Η', 'i'), ('Θ', 'th'), ('Ι', 'i'), ('Κ', 'k'),
    ('Λ', 'l'), ('Μ', 'm'), ('Ν', 'n'), ('Ξ', 'x'), ('Ο', 'o'), ('Π', 'p'), ('Ρ', 'r'), ('Σ', 's'), ('Τ', 't'), ('Υ', 'y'),
    ('Φ', 'f'), ('Χ', 'ch'), ('Ψ', 'ps'), ('Ω', 'o'),
  ]),
  ('daHebrew', [
    ('א', 'ʾ'), ('ב', 'b/v'), ('ג', 'g'), ('ד', 'd'), ('ה', 'h'), ('ו', 'v'), ('ז', 'z'), ('ח', 'ḥ'), ('ט', 't'), ('י', 'y'),
    ('כ', 'k/kh'), ('ל', 'l'), ('מ', 'm'), ('נ', 'n'), ('ס', 's'), ('ע', 'ʿ'), ('פ', 'p/f'), ('צ', 'ts'), ('ק', 'k'), ('ר', 'r'),
    ('ש', 'sh'), ('ת', 't'),
  ]),
];

class ScriptPuzzle extends EPuzzle {
  final int script;
  final List<int> letters;
  const ScriptPuzzle(this.script, this.letters);
}

class DunyaAlfabeleriKind extends EgiticiKind {
  const DunyaAlfabeleriKind();
  @override
  String get id => 'dunya-alfabeleri';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final s = r.nextInt(kScripts.length);
    final all = kScripts[s].$2.length;
    // Kolay bölümler alfabenin başından, zor bölümler bütün alfabeden.
    final span = math.min<int>(all, 8 + d * 4);
    final n = 3 + d ~/ 4;
    final pool = [for (var i = 0; i < span; i++) i];
    r.shuffle(pool);
    return ScriptPuzzle(s, (pool.take(n).toList()..sort()));
  }

  @override
  bool check(EPuzzle p) =>
      p is ScriptPuzzle &&
      p.script < kScripts.length &&
      p.letters.length >= 3 &&
      p.letters.toSet().length == p.letters.length &&
      p.letters.every((i) => i >= 0 && i < kScripts[p.script].$2.length);

  @override
  Widget build(EPlay play) {
    final p = play.puzzle as ScriptPuzzle;
    final sc = kScripts[p.script];
    return traceView(
      play,
      TracePuzzle([for (final i in p.letters) (0, i)], 0),
      glyphAt: (i) => sc.$2[p.letters[i]].$1,
      labelAt: (i) => '${et(play.lang, sc.$1)} · ${sc.$2[p.letters[i]].$1} = ${sc.$2[p.letters[i]].$2}',
    );
  }
}
