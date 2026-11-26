import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../studio_chrome.dart';
import '../texts.dart';
import 'store.dart';
import 'vis.dart';

/// Tek soru: bir görsel ve büyük seçenek kutuları.
class QItem {
  final Vis? prompt;
  final List<Vis> options;
  final int answer;

  /// Soru açılınca çalan ses (ör. hayvan sesi, nota); boşsa yok.
  final String sound;

  /// Doğru cevaptan sonra kısa süre gösterilen nazik öneri (metin anahtarı); boşsa yok.
  final String tip;

  /// Öneri kartındaki görsel.
  final Vis? tipVis;
  const QItem(this.prompt, this.options, this.answer, {this.sound = '', this.tip = '', this.tipVis});
}

/// Soru dizisi bölümü. [race]: matematik yarışı pisti; [grid]: farklı olanı bul.
class QuizPuzzle extends EPuzzle {
  final List<QItem> items;
  final bool race;
  final bool grid;
  const QuizPuzzle(this.items, {this.race = false, this.grid = false});
}

/// Genel denetim: en az bir soru, geçerli cevap, ayrık seçenekler.
bool checkQuiz(EPuzzle p) {
  if (p is! QuizPuzzle || p.items.isEmpty) return false;
  for (final it in p.items) {
    if (it.options.length < 2 || it.answer < 0 || it.answer >= it.options.length) return false;
    if (p.grid) {
      final odd = it.options[it.answer].key;
      if (it.options.where((o) => o.key == odd).length != 1) return false;
      continue;
    }
    final keys = it.options.map((o) => o.key).toSet();
    if (keys.length != it.options.length) return false;
  }
  return true;
}

/// Doğru seçeneği karıştırılmış listeye yerleştirir; cevabın sırasını döndürür.
(List<Vis>, int) mix(Vis right, List<Vis> wrong, SeededRandom r) {
  final all = [right, ...wrong];
  final order = List<int>.generate(all.length, (i) => i);
  r.shuffle(order);
  final out = [for (final i in order) all[i]];
  return (out, order.indexOf(0));
}

QItem qi(Vis? prompt, Vis right, List<Vis> wrong, SeededRandom r, {String sound = '', String tip = '', Vis? tipVis}) {
  final (opts, ans) = mix(right, wrong, r);
  return QItem(prompt, opts, ans, sound: sound, tip: tip, tipVis: tipVis);
}

/// [n] farklı tamsayı seç (0..[max]-1), [avoid] hariç.
List<int> distinct(SeededRandom r, int max, int n, {Set<int> avoid = const {}}) {
  final out = <int>[];
  var guard = 0;
  while (out.length < n && guard++ < 500) {
    final v = r.nextInt(max);
    if (!out.contains(v) && !avoid.contains(v)) out.add(v);
  }
  return out;
}

/// Soru dizisi ekranı: büyük kutular, yanlışta sarsılma, doğruda yeşil;
/// zorlanan çocuğa seçenek azaltılır (uyarlanabilir zorluk).
class QuizView extends StatefulWidget {
  final EPlay play;
  final QuizPuzzle q;
  const QuizView({super.key, required this.play, required this.q});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> with Clock<QuizView> {
  int idx = 0;
  int mistakes = 0;
  int streakWrong = 0;
  int extraHide = 0;
  final Set<int> wrong = {};
  int? okAt;
  bool showTip = false;
  int rival = 0;
  late int skill;

  EPlay get play => widget.play;
  QItem get item => widget.q.items[idx];

  @override
  void initState() {
    super.initState();
    skill = KidStore.instance.skill(play.gameId);
    startClock();
    _onItem();
    if (widget.q.race) _rivalTick();
  }

  void _rivalTick() {
    later(math.max<int>(2600, 7000 - play.d * 380), () {
      if (ended) return;
      setState(() => rival = math.min<int>(rival + 1, widget.q.items.length));
      if (rival < widget.q.items.length) _rivalTick();
    });
  }

  void _onItem() {
    final snd = item.sound;
    if (snd.isNotEmpty) later(350, () => play.sound(snd));
  }

  /// Gösterilecek seçenekler: beceri düşükse ve zorlanınca yanlışlar azalır.
  List<int> _visible() {
    final n = item.options.length;
    final hide = clampI((skill < 2 ? 2 - skill : 0) + extraHide, 0, n - 2);
    if (widget.q.grid || hide == 0) return [for (var i = 0; i < n; i++) i];
    final out = <int>[];
    var left = hide;
    for (var i = n - 1; i >= 0; i--) {
      if (left > 0 && i != item.answer && !wrong.contains(i)) {
        left--;
        continue;
      }
      out.add(i);
    }
    return out.reversed.toList();
  }

  void _tap(int i) {
    if (ended || okAt != null || wrong.contains(i)) return;
    if (i == item.answer) {
      play.sfx(Sfx.clear);
      play.answer(true);
      final tip = item.tip.isNotEmpty;
      setState(() {
        okAt = i;
        streakWrong = 0;
        showTip = tip;
      });
      later(tip ? 2600 : 650, _next);
    } else {
      play.sfx(Sfx.error);
      play.answer(false);
      setState(() {
        wrong.add(i);
        mistakes++;
        streakWrong++;
        if (streakWrong >= 2) extraHide++;
      });
    }
  }

  void _next() {
    if (ended) return;
    if (idx + 1 >= widget.q.items.length) {
      ended = true;
      final total = widget.q.items.length;
      if (mistakes == 0) {
        KidStore.instance.setSkill(play.gameId, skill + 1);
      } else if (mistakes * 2 >= total) {
        KidStore.instance.setSkill(play.gameId, skill - 1);
      }
      play.finish(mistakes: mistakes, seconds: seconds);
      return;
    }
    setState(() {
      idx++;
      okAt = null;
      showTip = false;
      wrong.clear();
      extraHide = 0;
    });
    _onItem();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final vis = _visible();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 700.0;
      final cols = q.grid ? (vis.length <= 4 ? 2 : (vis.length <= 9 ? 3 : 4)) : (vis.length <= 4 ? 2 : 3);
      final rows = (vis.length + cols - 1) ~/ cols;
      final promptH = item.prompt == null ? 0.0 : math.min(h * 0.36, w * 0.62);
      final raceH = q.race ? 54.0 : 0.0;
      final avail = h - promptH - raceH - 70;
      final tile = clampD(math.min((w - 24) / cols - 12, avail / rows - 12), 56, 220);
      final body = Column(children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: idx, total: q.items.length)),
        if (q.race) SizedBox(height: raceH, child: _RaceTrack(me: idx + (okAt == null ? 0 : 1), rival: rival, total: q.items.length)),
        if (item.prompt != null)
          SizedBox(
            height: promptH,
            child: Center(
              child: GestureDetector(
                onTap: item.sound.isEmpty ? null : () => play.sound(item.sound),
                child: Container(
                  width: promptH * 1.25,
                  height: promptH * 0.94,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: KColors.line, width: 2),
                  ),
                  child: Center(child: VisView(v: item.prompt!, lang: play.lang, size: promptH * 0.82)),
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final i in vis)
                  _OptionTile(
                    key: ValueKey('o$idx-$i'),
                    size: tile,
                    color: okAt == i ? const Color(0xFFCDEBD3) : (wrong.contains(i) ? const Color(0xFFF1E3DF) : KColors.tiles[i % KColors.tiles.length]),
                    dim: wrong.contains(i),
                    shake: wrong.contains(i),
                    onTap: () => _tap(i),
                    child: VisView(v: item.options[i], lang: play.lang, size: tile * 0.86),
                  ),
              ],
            ),
          ),
        ),
      ]);
      if (!showTip) return body;
      final tv = item.tipVis;
      final tipW = math.min(w - 32, 460.0);
      return Stack(children: [
        body,
        Positioned(
          left: (w - tipW) / 2,
          width: tipW,
          bottom: 16,
          child: Material(
            color: StudioLook.of(context).sheet,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: StudioLook.of(context).accent.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                if (tv != null)
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: VisView(v: tv, lang: play.lang, size: 64),
                  ),
                if (tv != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(et(play.lang, item.tip),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
                ),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}

class _OptionTile extends StatelessWidget {
  final double size;
  final Color color;
  final bool dim;
  final bool shake;
  final VoidCallback onTap;
  final Widget child;
  const _OptionTile({super.key, required this.size, required this.color, required this.dim, required this.shake, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: dim ? 0.45 : 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        elevation: 1.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Center(child: child)),
        ),
      ),
    );
    if (!shake) return tile;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (context, t, ch) => Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 8 * (1 - t), 0), child: ch),
      child: tile,
    );
  }
}

class _RaceTrack extends StatelessWidget {
  final int me;
  final int rival;
  final int total;
  const _RaceTrack({required this.me, required this.rival, required this.total});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth - 60;
      double x(int v) => 10 + w * clampD(v / total, 0, 1);
      return Stack(children: [
        Positioned(left: 10, right: 10, top: 22, child: Container(height: 10, decoration: BoxDecoration(color: KColors.soft, borderRadius: BorderRadius.circular(5)))),
        const Positioned(right: 6, top: 6, child: Text('🏁', style: TextStyle(fontSize: 28))),
        AnimatedPositioned(duration: const Duration(milliseconds: 500), left: x(rival), top: 0, child: const Opacity(opacity: 0.6, child: Text('🐢', style: TextStyle(fontSize: 26)))),
        AnimatedPositioned(duration: const Duration(milliseconds: 500), left: x(me), top: 20, child: const Text('🚗', style: TextStyle(fontSize: 28))),
      ]);
    });
  }
}
