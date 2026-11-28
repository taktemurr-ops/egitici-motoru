import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/words.dart';
import '../kid/vis.dart';
import '../texts.dart';
import 'strokes.dart';

// ---------------------------------------------------------------- harf izleme

class TracePuzzle extends EPuzzle {
  /// (tür, sıra): tür 0 büyük harf, 1 küçük harf, 2 rakam.
  final List<(int, int)> items;
  final int offset;
  const TracePuzzle(this.items, this.offset);
}

class HarfIzlemeKind extends EgiticiKind {
  const HarfIzlemeKind();
  @override
  String get id => 'harf-izleme';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final n = 3 + d ~/ 3;
    final items = <(int, int)>[];
    final seen = <String>{};
    var g = 0;
    while (items.length < n && g++ < 100) {
      final t = d <= 1 ? 0 : (d <= 3 ? (r.chance(0.7) ? 0 : 2) : r.nextInt(3));
      final i = t == 2 ? r.nextInt(10) : r.nextInt(20);
      if (seen.add('$t:$i')) items.add((t, i));
    }
    if (items.length < n) return null;
    return TracePuzzle(items, r.nextInt(997));
  }

  @override
  bool check(EPuzzle p) =>
      p is TracePuzzle && p.items.length >= 3 && p.items.every((it) => it.$1 >= 0 && it.$1 <= 2 && it.$2 >= 0 && it.$2 < (it.$1 == 2 ? 10 : 20));

  @override
  Widget build(EPlay play) => _TraceView(play: play, p: play.puzzle as TracePuzzle);
}

const int _g = 40; // örnekleme ızgarası
const double _side = 200;

/// İzleme ekranı; [glyphAt] verilirse arayüz dilinin harfleri yerine onu
/// izletir (Dünya Alfabeleri), [labelAt] harfin okunuşunu üstte gösterir.
Widget traceView(EPlay play, TracePuzzle p, {String Function(int i)? glyphAt, String Function(int i)? labelAt}) =>
    _TraceView(play: play, p: p, glyphAt: glyphAt, labelAt: labelAt);

class _TraceView extends StatefulWidget {
  final EPlay play;
  final TracePuzzle p;
  final String Function(int i)? glyphAt;
  final String Function(int i)? labelAt;
  const _TraceView({required this.play, required this.p, this.glyphAt, this.labelAt});

  @override
  State<_TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<_TraceView> with Clock<_TraceView>, SingleTickerProviderStateMixin {
  int idx = 0;
  /// Çizgi sırası rehberi: harfin kutusuna oturtulmuş çizgiler (verisi
  /// olmayan harflerde null; o zaman yalnız [_start] başlangıç noktası).
  List<List<Offset>>? _guide;
  Offset? _start;
  late final AnimationController _demo = AnimationController(vsync: this)..addListener(() => setState(() {}));
  Timer? _idleT;
  int _idle = 0;
  int clears = 0;
  Set<int>? mask;
  final Set<int> painted = {};
  final List<List<Offset>> strokes = [];
  int _job = 0;

  String get glyph {
    final f = widget.glyphAt;
    if (f != null) return f(idx);
    final it = widget.p.items[idx];
    final lang = widget.play.lang;
    if (it.$1 == 2) return numL(it.$2, lang);
    return letterAt(lang, it.$2, widget.p.offset, lower: it.$1 == 1);
  }

  @override
  void initState() {
    super.initState();
    startClock();
    _buildMask();
    later(450, _sayGlyph);
    // Uzun süre dokunulmazsa çizgi sırası yeniden gösterilir.
    _idleT = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || ended || _demo.isAnimating) return;
      if (++_idle >= 8) _showDemo();
    });
  }

  void _showDemo() {
    _idle = 0;
    final g = _guide;
    if (g == null || g.isEmpty || ended) return;
    _demo.duration = Duration(milliseconds: 950 * g.length);
    _demo.forward(from: 0);
  }

  void _hear() {
    _sayGlyph();
    _showDemo();
  }

  /// Kendi alfabesinin harfi/rakamı okunur (başka yazılarda okunuş belirsiz).
  void _sayGlyph() {
    if (widget.glyphAt == null) widget.play.say(glyph);
  }

  @override
  void dispose() {
    _idleT?.cancel();
    _demo.dispose();
    widget.play.hush();
    super.dispose();
  }

  TextPainter _tp(Color c) => TextPainter(
        text: TextSpan(text: glyph, style: TextStyle(fontSize: 150, fontWeight: FontWeight.w800, color: c, height: 1.0)),
        textDirection: TextDirection.ltr,
      )..layout();

  Future<void> _buildMask() async {
    final job = ++_job;
    mask = null;
    _guide = null;
    _start = null;
    _demo.stop();
    _demo.value = 0;
    if (job > 1) setState(() {});
    try {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final tp = _tp(Colors.black);
      tp.paint(c, Offset((_side - tp.width) / 2, (_side - tp.height) / 2));
      final img = await rec.endRecording().toImage(_side.toInt(), _side.toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || job != _job || !mounted) return;
      final m = <int>{};
      final step = _side / _g;
      for (var gy = 0; gy < _g; gy++) {
        for (var gx = 0; gx < _g; gx++) {
          final px = ((gx + 0.5) * step).toInt(), py = ((gy + 0.5) * step).toInt();
          final a = data.getUint8((py * _side.toInt() + px) * 4 + 3);
          if (a > 100) m.add(gy * _g + gx);
        }
      }
      // Harfin gerçek kutusu (çizgileri yazı tipinden bağımsız oturtmak için).
      final sw = _side.toInt();
      var l = sw, t = sw, r = -1, b = -1;
      for (var y = 0; y < sw; y++) {
        for (var x = 0; x < sw; x++) {
          if (data.getUint8((y * sw + x) * 4 + 3) > 100) {
            if (x < l) l = x;
            if (x > r) r = x;
            if (y < t) t = y;
            if (y > b) b = y;
          }
        }
      }
      List<List<Offset>>? guide;
      Offset? start;
      final raw = strokesFor(glyph);
      if (raw != null && r >= l && b >= t) {
        guide = fitStrokes(raw, Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0));
      }
      if (guide == null && m.isNotEmpty) {
        // Verisi olmayan harf: yazının yönüne göre en üst satırın ilk hücresi.
        final rtlScript = glyph.runes.any((c) => c >= 0x0590 && c <= 0x08FF);
        final top = m.reduce(math.min) ~/ _g;
        final row = m.where((i) => i ~/ _g == top);
        final cell = rtlScript ? row.reduce(math.max) : row.reduce(math.min);
        start = Offset((cell % _g + 0.5) * step, (cell ~/ _g + 0.5) * step);
      }
      if (mounted && job == _job) {
        setState(() {
          mask = m;
          _guide = guide;
          _start = start;
        });
        later(500, _showDemo);
      }
    } catch (_) {}
  }

  void _add(Offset o) {
    if (ended) return;
    _idle = 0;
    if (_demo.isAnimating) {
      _demo.stop();
      _demo.value = 0;
    }
    strokes.last.add(o);
    final step = _side / _g;
    const rad = 13.0;
    final x0 = ((o.dx - rad) / step).floor(), x1 = ((o.dx + rad) / step).floor();
    final y0 = ((o.dy - rad) / step).floor(), y1 = ((o.dy + rad) / step).floor();
    for (var gy = math.max<int>(0, y0); gy <= math.min<int>(_g - 1, y1); gy++) {
      for (var gx = math.max<int>(0, x0); gx <= math.min<int>(_g - 1, x1); gx++) {
        final c = Offset((gx + 0.5) * step, (gy + 0.5) * step);
        if ((c - o).distance <= rad) painted.add(gy * _g + gx);
      }
    }
    setState(() {});
  }

  void _end() {
    final m = mask;
    if (m == null || m.isEmpty || ended) return;
    final hit = painted.where(m.contains).length;
    final cover = hit / m.length;
    final outside = painted.isEmpty ? 0.0 : (painted.length - hit) / painted.length;
    if (cover >= 0.7 && outside <= 0.55) {
      widget.play.sfx(Sfx.clear);
      widget.play.answer(true);
      widget.play.say(et(widget.play.lang, 'praise${(idx % 3) + 1}'));
      ended = idx + 1 >= widget.p.items.length;
      later(900, () {
        if (idx + 1 >= widget.p.items.length) {
          widget.play.finish(mistakes: clears, seconds: seconds);
          return;
        }
        setState(() {
          idx++;
          painted.clear();
          strokes.clear();
        });
        _buildMask();
        later(350, _sayGlyph);
      });
    }
  }

  void _clear() {
    widget.play.answer(false);
    setState(() {
      clears++;
      painted.clear();
      strokes.clear();
    });
  }

  /// Çizginin örnek noktalarının en az %70'i boyandıysa çizgi tamamdır.
  bool _strokeDone(List<Offset> s) {
    final pts = samplePath(s, step: 5);
    if (pts.isEmpty) return true;
    final step = _side / _g;
    var hit = 0;
    for (final p in pts) {
      final gx = clampI((p.dx / step).floor(), 0, _g - 1), gy = clampI((p.dy / step).floor(), 0, _g - 1);
      if (painted.contains(gy * _g + gx)) hit++;
    }
    return hit / pts.length >= 0.7;
  }

  void _num(Canvas c, Offset at, int n, Color bg, {double r = 9}) {
    c.drawCircle(at, r + 2, fill(Colors.white));
    c.drawCircle(at, r, fill(bg));
    final tp = TextPainter(
      text: TextSpan(text: numL(n, widget.play.lang), style: TextStyle(fontSize: r * 1.25, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _arrow(Canvas c, Offset tip, Offset dir, Color col) {
    final n = Offset(-dir.dy, dir.dx);
    final p = Path()
      ..moveTo(tip.dx + dir.dx * 4, tip.dy + dir.dy * 4)
      ..lineTo(tip.dx - dir.dx * 7 + n.dx * 6, tip.dy - dir.dy * 7 + n.dy * 6)
      ..lineTo(tip.dx - dir.dx * 7 - n.dx * 6, tip.dy - dir.dy * 7 - n.dy * 6)
      ..close();
    c.drawPath(p, fill(col));
  }

  /// Çizgi sırası rehberi: sıradaki çizgi noktalı yol + ok + numaralı
  /// başlangıç noktası; diğer bitmemiş çizgilerin yalnız numarası.
  void _paintGuide(Canvas c) {
    const go = Color(0xFF1E9E57), path = Color(0xFFE8890C);
    final g = _guide;
    if (g == null) {
      final s = _start;
      if (s != null && painted.isEmpty) {
        c.drawCircle(s, 11, fill(Colors.white));
        c.drawCircle(s, 9, fill(go));
        c.drawCircle(s, 3.5, fill(Colors.white));
      }
      return;
    }
    if (_demo.isAnimating) {
      // Gösterim: parmak çizgileri sırayla izler.
      final f = _demo.value * g.length;
      final k = clampI(f.floor(), 0, g.length - 1);
      for (var j = 0; j <= k; j++) {
        final s = g[j];
        final part = j < k ? 1.0 : clampD(f - k, 0, 1);
        final pts = samplePath(s, step: 3);
        final upto = clampI((pts.length * part).round(), 1, pts.length);
        final pp = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final o in pts.take(upto).skip(1)) {
          pp.lineTo(o.dx, o.dy);
        }
        c.drawPath(pp, stroke(path.withValues(alpha: 0.75), 7));
        if (j == k) {
          final (at, _) = pointAlong(s, part);
          c.drawCircle(at, 13, fill(path.withValues(alpha: 0.30)));
          c.drawCircle(at, 7, fill(path));
        }
      }
      for (var j = 0; j < g.length; j++) {
        _num(c, g[j].first, j + 1, go, r: 7);
      }
      return;
    }
    final done = [for (final s in g) _strokeDone(s)];
    final next = done.indexOf(false);
    if (next < 0) return;
    for (var j = g.length - 1; j >= 0; j--) {
      if (done[j] || j == next) continue;
      _num(c, g[j].first, j + 1, go.withValues(alpha: 0.45), r: 7);
    }
    final s = g[next];
    final pts = samplePath(s, step: 7);
    for (final o in pts.skip(1).take(math.max(0, pts.length - 2))) {
      c.drawCircle(o, 2.4, fill(path));
    }
    if (s.length >= 2) {
      final (tip, dir) = pointAlong(s, 1.0);
      _arrow(c, tip, dir, path);
    }
    _num(c, s.first, next + 1, go);
  }

  void _paint(Canvas c) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, _side, _side), const Radius.circular(18)), fill(Colors.white));
    final tp = _tp(const Color(0xFFE4DED2));
    tp.paint(c, Offset((_side - tp.width) / 2, (_side - tp.height) / 2));
    final m = mask;
    if (m != null) {
      final step = _side / _g;
      for (final i in painted) {
        if (m.contains(i)) {
          c.drawRect(Rect.fromLTWH((i % _g) * step, (i ~/ _g) * step, step + 0.5, step + 0.5), fill(const Color(0x553E8E5F)));
        }
      }
    }
    _paintGuide(c);
    for (final s in strokes) {
      if (s.length < 2) {
        if (s.isNotEmpty) c.drawCircle(s.first, 7, fill(const Color(0xFF4F86C6)));
        continue;
      }
      final p = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      c.drawPath(p, stroke(const Color(0xFF4F86C6), 14));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = mask;
    final cover = m == null || m.isEmpty ? 0.0 : painted.where(m.contains).length / m.length;
    final label = widget.labelAt;
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: idx, total: widget.p.items.length)),
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(label(idx), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(children: [
          if (widget.glyphAt == null)
            IconButton(tooltip: et(widget.play.lang, 'hear'), onPressed: _hear, icon: const Icon(Icons.volume_up_rounded, size: 30)),
          Expanded(child: LinearProgressIndicator(value: clampD(cover / 0.7, 0, 1), minHeight: 10, borderRadius: BorderRadius.circular(5))),
          IconButton(tooltip: et(widget.play.lang, 'clear'), onPressed: _clear, icon: const Icon(Icons.cleaning_services_outlined, size: 30)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TapCanvas(
            w: _side,
            h: _side,
            paint: _paint,
            onPanStart: (o) {
              strokes.add([]);
              _add(o);
            },
            onPanUpdate: _add,
            onPanEnd: _end,
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- hece okuma

class SyllPuzzle extends EPuzzle {
  final List<int> words;
  final int distractors;
  const SyllPuzzle(this.words, this.distractors);
}

class HeceKind extends EgiticiKind {
  const HeceKind();
  @override
  String get id => 'hece';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final n = 4 + d ~/ 3;
    final pool = List<int>.generate(kWordKeys.length, (i) => i);
    r.shuffle(pool);
    return SyllPuzzle(pool.take(n).toList(), d <= 2 ? 1 : (d <= 6 ? 2 : 3));
  }

  @override
  bool check(EPuzzle p) => p is SyllPuzzle && p.words.length >= 4 && p.words.toSet().length == p.words.length && p.words.every((w) => w >= 0 && w < kWordKeys.length);

  @override
  Widget build(EPlay play) => _SyllView(play: play, p: play.puzzle as SyllPuzzle);
}

class _SyllView extends StatefulWidget {
  final EPlay play;
  final SyllPuzzle p;
  const _SyllView({required this.play, required this.p});

  @override
  State<_SyllView> createState() => _SyllViewState();
}

class _SyllViewState extends State<_SyllView> with Clock<_SyllView> {
  int idx = 0;
  int placed = 0;
  int mistakes = 0;
  late List<String> parts;
  late List<(String, bool)> tiles; // (metin, doğru parça mı)
  final Set<int> used = {};
  int? wrongAt;

  List<List<String>> get table => kSyllables[widget.play.lang] ?? kSyllables['en']!;

  @override
  void initState() {
    super.initState();
    startClock();
    _setup();
  }

  void _setup() {
    final w = widget.p.words[idx];
    parts = table[w];
    final r = SeededRandom(mixSeed([widget.play.seed, idx, 77]));
    final extra = <String>[];
    var g = 0;
    while (extra.length < widget.p.distractors && g++ < 50) {
      final other = table[r.nextInt(table.length)];
      final s = r.pick(other).trim();
      if (!parts.map((x) => x.trim()).contains(s) && !extra.contains(s)) extra.add(s);
    }
    tiles = [for (final s in parts) (s.trim(), true), for (final s in extra) (s, false)];
    r.shuffle(tiles);
    used.clear();
    placed = 0;
    // Sözcük önce bütün olarak okunur; çocuk heceleri duyarak kurar.
    later(450, _sayWord);
  }

  String get _word => nm(kWordKeys[widget.p.words[idx]], widget.play.lang);

  void _sayWord() => widget.play.say(_word);

  @override
  void dispose() {
    widget.play.hush();
    super.dispose();
  }

  void _tap(int i) {
    if (ended || used.contains(i)) return;
    final want = parts[placed].trim();
    if (tiles[i].$1 == want) {
      widget.play.sfx(Sfx.place);
      widget.play.answer(true);
      // Hece okunur; son hecede sözcüğün tamamı.
      if (placed + 1 >= parts.length) {
        widget.play.say(_word);
      } else {
        widget.play.say(want);
      }
      setState(() {
        used.add(i);
        placed++;
        wrongAt = null;
      });
      if (placed >= parts.length) {
        widget.play.sfx(Sfx.clear);
        later(1300, () {
          if (idx + 1 >= widget.p.words.length) {
            ended = true;
            widget.play.finish(mistakes: mistakes, seconds: seconds);
            return;
          }
          setState(() {
            idx++;
            _setup();
          });
        });
      }
    } else {
      widget.play.sfx(Sfx.error);
      widget.play.answer(false);
      setState(() {
        mistakes++;
        wrongAt = i;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.p.words[idx];
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: idx, total: widget.p.words.length)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(kWordEmoji[w], style: const TextStyle(fontSize: 96)),
        const SizedBox(width: 10),
        BigButton(size: 56, color: KColors.accent, tooltip: et(widget.play.lang, 'hear'), onTap: _sayWord, child: const Icon(Icons.volume_up_rounded, size: 30)),
      ]),
      const SizedBox(height: 8),
      Directionality(
        textDirection: widget.play.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < parts.length; i++)
            Container(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: i < placed ? const Color(0xFFCDEBD3) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: i == placed ? KColors.accent : KColors.line, width: i == placed ? 3 : 2),
              ),
              // Kutu yazı kadar geniş (satırın tamamını kaplamaz).
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(i < placed ? parts[i].trim() : '', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: KColors.ink)),
              ),
            ),
        ]),
      ),
      Expanded(
        child: Center(
          child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < tiles.length; i++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: used.contains(i) ? 0.15 : 1,
                child: Material(
                  color: wrongAt == i ? const Color(0xFFF1E3DF) : KColors.tiles[i % KColors.tiles.length],
                  borderRadius: BorderRadius.circular(18),
                  elevation: 1.5,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _tap(i),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 84, minHeight: 84),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      // Kutu yazı kadar geniş (satırın tamamını kaplayıp ekran dışına itmez).
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(tiles[i].$1, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: KColors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}
