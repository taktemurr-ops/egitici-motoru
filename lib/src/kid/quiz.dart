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

  /// Uzun süre dokunulmayınca (küçük zorlukta) doğru kutu nazikçe parlar.
  bool nudge = false;
  int _token = 0;

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
    // Yazılı soru okunur: okuma bilmeyen çocuk da ne sorulduğunu duyar.
    final pv = item.prompt;
    final say = pv == null ? null : visText(pv, play.lang);
    if (say != null) later(snd.isNotEmpty ? 1700 : 450, () => play.say(say.$1, say.$2));
    final my = ++_token;
    if (play.d <= 3 || skill < 1) {
      later(9000, () {
        if (!ended && my == _token && okAt == null) setState(() => nudge = true);
      });
    }
  }

  /// Hoparlör: sesi ve yazılı soruyu yeniden dinletir.
  void _replay() {
    final snd = item.sound;
    if (snd.isNotEmpty) play.sound(snd);
    final pv = item.prompt;
    final say = pv == null ? null : visText(pv, play.lang);
    if (say != null) later(snd.isNotEmpty ? 1400 : 0, () => play.say(say.$1, say.$2));
  }

  bool get _canReplay {
    final pv = item.prompt;
    return item.sound.isNotEmpty || (pv != null && visText(pv, play.lang) != null);
  }

  @override
  void dispose() {
    play.hush();
    super.dispose();
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
      // Pekiştirme: doğru cevabın adı söylenir ("İnek!"), adı yoksa övgü.
      final right = item.options[i];
      final t = visText(right, play.lang);
      final pv = item.prompt;
      final pt = pv == null ? null : visText(pv, play.lang);
      final name = visName(right, play.lang);
      if (item.tip.isNotEmpty) {
        // Öneri kartı okunur (okuma bilmeyen çocuk da duysun).
        play.say(et(play.lang, item.tip));
      } else if (t != null) {
        play.say(t.$1, t.$2);
      } else if (name != null) {
        play.say(name);
      } else if (pt != null && pt.$2 != play.lang) {
        play.say(pt.$1, pt.$2);
      } else {
        play.say(et(play.lang, 'praise${(idx % 3) + 1}'));
      }
      final tip = item.tip.isNotEmpty;
      setState(() {
        okAt = i;
        streakWrong = 0;
        showTip = tip;
        nudge = false;
      });
      // Söylenen ad duyulsun diye kısa bir bekleme (ses kapalıysa da aynı ritim).
      later(tip ? (KidStore.instance.voiceOn ? 4200 : 2600) : 1050, _next);
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
      nudge = false;
      wrong.clear();
      extraHide = 0;
    });
    _onItem();
  }

  /// Yazılı seçeneğin köşesindeki hoparlör: seçeneği dinletir (seçmez).
  VoidCallback? _speakerFor(Vis v) {
    final t = visText(v, play.lang);
    if (t == null) return null;
    return () => play.say(t.$1, t.$2);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final vis = _visible();
    return KidPlaymat(kind: play.kind, child: LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 700.0;
      final cols = q.grid ? (vis.length <= 4 ? 2 : (vis.length <= 9 ? 3 : 4)) : (vis.length <= 4 ? 2 : 3);
      final rows = (vis.length + cols - 1) ~/ cols;
      final promptH = item.prompt == null ? 0.0 : math.min(h * 0.36, w * 0.62);
      final raceH = q.race ? 54.0 : 0.0;
      final avail = h - promptH - raceH - 84;
      final tile = clampD(math.min((w - 24) / cols - 12, avail / rows - 12), 56, 220);
      final body = Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), borderRadius: BorderRadius.circular(14)),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: StepDots(done: idx, total: q.items.length)),
          ),
        ),
        if (q.race) SizedBox(height: raceH, child: _RaceTrack(me: idx + (okAt == null ? 0 : 1), rival: rival, total: q.items.length)),
        if (item.prompt != null)
          SizedBox(
            height: promptH,
            child: Center(
              child: Stack(clipBehavior: Clip.none, children: [
                GestureDetector(
                  onTap: _canReplay ? _replay : null,
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
                if (_canReplay)
                  PositionedDirectional(
                    end: 6,
                    bottom: 6,
                    child: _SpeakBadge(size: 52, tooltip: et(play.lang, 'hear'), onTap: _replay),
                  ),
              ]),
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
                    glow: nudge && i == item.answer,
                    onTap: () => _tap(i),
                    onSpeak: q.grid ? null : _speakerFor(item.options[i]),
                    speakTip: et(play.lang, 'hear'),
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
    }));
  }
}

class _OptionTile extends StatelessWidget {
  final double size;
  final Color color;
  final bool dim;
  final bool shake;
  final bool glow;
  final VoidCallback onTap;
  final VoidCallback? onSpeak;
  final String speakTip;
  final Widget child;
  const _OptionTile(
      {super.key,
      required this.size,
      required this.color,
      required this.dim,
      required this.shake,
      required this.onTap,
      required this.child,
      this.glow = false,
      this.onSpeak,
      this.speakTip = ''});

  @override
  Widget build(BuildContext context) {
    final sp = onSpeak;
    Widget tile = _plain();
    if (glow) tile = _Glow(child: tile);
    if (sp != null && size >= 72) {
      final b = clampD(size * 0.3, 34, 48);
      tile = Stack(clipBehavior: Clip.none, children: [
        tile,
        PositionedDirectional(top: 4, end: 4, child: _SpeakBadge(size: b, tooltip: speakTip, onTap: sp)),
      ]);
    }
    if (!shake) return tile;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (context, t, ch) => Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 8 * (1 - t), 0), child: ch),
      child: tile,
    );
  }

  Widget _plain() {
    return AnimatedOpacity(
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
  }
}

/// Küçük yuvarlak hoparlör düğmesi (dinle).
class _SpeakBadge extends StatelessWidget {
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  const _SpeakBadge({required this.size, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KColors.accent,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2.5)),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(Icons.volume_up_rounded, color: Colors.white, size: size * 0.58)),
        ),
      ),
    );
  }
}

/// Doğru kutunun nazik parıltısı (uzun süre dokunulmayınca ipucu): bir kez
/// büyüyüp yerleşir, sonra altın hâle olarak kalır (sonsuz animasyon yok).
class _Glow extends StatelessWidget {
  final Widget child;
  const _Glow({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      child: child,
      builder: (context, v, ch) => Transform.scale(
        scale: 1 + 0.06 * v,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: StudioLook.gold, width: 4),
            boxShadow: [BoxShadow(color: StudioLook.gold.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 3)],
          ),
          child: ch,
        ),
      ),
    );
  }
}

/// Oyun alanı teması: her soru oyununun kendi zemini (renk geçişi ve silik
/// motif deseni). Aynı soru motorunu kullanan oyunlar oyun içinde de ayrı
/// görünür; çerçeve (çıkartma, ebeveyn düğmesi) onaylı tasarımda kalır.
const Map<String, (int, int, String)> kKidThemes = {
  'alfabe': (0xFFFFEDBF, 0xFFFFC96B, '✏️'),
  'sayi': (0xFFDDF3FF, 0xFF9AD0F5, '🔢'),
  'saat': (0xFFECE6FF, 0xFFB9A7F0, '⏰'),
  'sekil-renk': (0xFFFFE4EE, 0xFFF7A8C4, '🔺'),
  'geometri': (0xFFE3F7EE, 0xFF92D8B5, '🔷'),
  'matematik-yarisi': (0xFFE9F4DC, 0xFFA9D18E, '🏁'),
  'carpim': (0xFFFFEDDA, 0xFFF5B37A, '✖️'),
  'toplama-cikarma': (0xFFE3F5FF, 0xFF8CCBEB, '➕'),
  'kesirler': (0xFFFFF1E3, 0xFFF2BE8A, '🍕'),
  'para-sayma': (0xFFFFF6D8, 0xFFE8CD6A, '💰'),
  'bayraklar': (0xFFE6EDFF, 0xFFA3B9F0, '🚩'),
  'baskentler': (0xFFE4F2F8, 0xFF94C6DD, '🗺️'),
  'gunes-sistemi': (0xFF2E3466, 0xFF141833, '✨'),
  'mevsimler': (0xFFEAF7E2, 0xFFB7DE9E, '🍃'),
  'trafik': (0xFFECEEF1, 0xFFB8C0C8, '🚦'),
  'hayvanlar': (0xFFF5EEE1, 0xFFD7BF94, '🐾'),
  'ingilizce': (0xFFE6F0FF, 0xFFF2C5CF, '🔤'),
  'dikkat': (0xFFF3E9FF, 0xFFC9AEF2, '🔍'),
  'nota': (0xFFFFF1F6, 0xFFF0B4CB, '🎵'),
  'duygular': (0xFFFFF3E0, 0xFFF6C98F, '💛'),
  'zit-kavramlar': (0xFFE9F1F8, 0xFFF4DDBE, '↔️'),
  'yonler': (0xFFE6F7F4, 0xFF9AD6CA, '🧭'),
  'saglikli-aliskanliklar': (0xFFE8F8EC, 0xFFA5DDB3, '🍎'),
  'meslekler': (0xFFF1ECE5, 0xFFCDB89C, '🧰'),
  'vucudumuz': (0xFFFFEBE8, 0xFFF3B3A8, '❤️'),
  'dinozorlar': (0xFFE8EFDB, 0xFFB4C58C, '🦕'),
  'meyve-sebze': (0xFFFFF2DF, 0xFFB9DB8E, '🍓'),
};

class KidPlaymat extends StatelessWidget {
  final String kind;
  final Widget child;
  const KidPlaymat({super.key, required this.kind, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = kKidThemes[kind];
    if (t == null) return child;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(t.$1), Color(t.$2)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _MotifPainter(t.$3)))),
        child,
      ]),
    );
  }
}

/// Silik, çapraz dizili motif (dokunuşa kapalı).
class _MotifPainter extends CustomPainter {
  final String motif;
  _MotifPainter(this.motif);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(text: TextSpan(text: motif, style: const TextStyle(fontSize: 26)), textDirection: TextDirection.ltr)..layout();
    const step = 74.0;
    final paint = Paint()..color = const Color(0x1F000000);
    canvas.saveLayer(Offset.zero & size, paint);
    var row = 0;
    for (var y = 8.0; y < size.height; y += step * 0.8, row++) {
      for (var x = (row.isOdd ? step / 2 : 0.0) + 8; x < size.width; x += step) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(row.isOdd ? 0.2 : -0.2);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) => old.motif != motif;
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
