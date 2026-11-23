import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/words.dart';
import '../kid/vis.dart';
import '../texts.dart';

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

class _TraceView extends StatefulWidget {
  final EPlay play;
  final TracePuzzle p;
  const _TraceView({required this.play, required this.p});

  @override
  State<_TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<_TraceView> with Clock<_TraceView> {
  int idx = 0;
  int clears = 0;
  Set<int>? mask;
  final Set<int> painted = {};
  final List<List<Offset>> strokes = [];
  int _job = 0;

  String get glyph {
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
  }

  TextPainter _tp(Color c) => TextPainter(
        text: TextSpan(text: glyph, style: TextStyle(fontSize: 150, fontWeight: FontWeight.w800, color: c, height: 1.0)),
        textDirection: TextDirection.ltr,
      )..layout();

  Future<void> _buildMask() async {
    final job = ++_job;
    mask = null;
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
      if (mounted && job == _job) setState(() => mask = m);
    } catch (_) {}
  }

  void _add(Offset o) {
    if (ended) return;
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
      ended = idx + 1 >= widget.p.items.length;
      later(600, () {
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
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: idx, total: widget.p.items.length)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(children: [
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
  }

  void _tap(int i) {
    if (ended || used.contains(i)) return;
    final want = parts[placed].trim();
    if (tiles[i].$1 == want) {
      widget.play.sfx(Sfx.place);
      widget.play.answer(true);
      setState(() {
        used.add(i);
        placed++;
        wrongAt = null;
      });
      if (placed >= parts.length) {
        widget.play.sfx(Sfx.clear);
        later(900, () {
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
      Text(kWordEmoji[w], style: const TextStyle(fontSize: 96)),
      const SizedBox(height: 8),
      Directionality(
        textDirection: widget.play.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < parts.length; i++)
            Container(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < placed ? const Color(0xFFCDEBD3) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: i == placed ? KColors.accent : KColors.line, width: i == placed ? 3 : 2),
              ),
              child: Text(i < placed ? parts[i].trim() : '', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
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
                      alignment: Alignment.center,
                      child: Text(tiles[i].$1, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: KColors.ink)),
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
