import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/art.dart';
import '../texts.dart';

// ---------------------------------------------------------------- boyama kitabı

class ColorPuzzle extends EPuzzle {
  /// 200×200 tuvalde bölgeler (x, y çiftleri); sonraki bölge üstte.
  final List<List<int>> regions;
  final int palette;
  const ColorPuzzle(this.regions, this.palette);
}

/// Bölge sayısı [rings] × [sectors] olan çiçekli mandala.
List<List<int>> mandala(SeededRandom r, int rings, int sectors) {
  final out = <List<int>>[];
  const cx = 100.0, cy = 100.0;
  final r0 = 14.0, r1 = 94.0;
  final step = (r1 - r0) / rings;
  final rot = r.nextDouble() * math.pi;
  for (var k = rings - 1; k >= 0; k--) {
    final a = r0 + k * step, b = a + step;
    final m = sectors * (k.isEven ? 1 : 2) ~/ (k == 0 ? 2 : 1);
    final petal = r.chance(0.5);
    for (var j = 0; j < m; j++) {
      final t0 = rot + j * 2 * math.pi / m, t1 = rot + (j + 1) * 2 * math.pi / m;
      final pts = <int>[];
      const n = 6;
      for (var i = 0; i <= n; i++) {
        final t = t0 + (t1 - t0) * i / n;
        final bulge = petal ? step * 0.35 * math.sin(math.pi * i / n) : 0.0;
        pts..add((cx + (b + bulge) * math.cos(t)).round())..add((cy + (b + bulge) * math.sin(t)).round());
      }
      for (var i = n; i >= 0; i--) {
        final t = t0 + (t1 - t0) * i / n;
        pts..add((cx + a * math.cos(t)).round())..add((cy + a * math.sin(t)).round());
      }
      out.add(pts);
    }
  }
  final c = <int>[];
  for (var i = 0; i < 16; i++) {
    final t = i * 2 * math.pi / 16;
    c..add((cx + r0 * math.cos(t)).round())..add((cy + r0 * math.sin(t)).round());
  }
  out.add(c);
  return out;
}

/// Kareli desen: karo içinde dönüşümlü şekiller.
List<List<int>> tiles(SeededRandom r, int n) {
  final out = <List<int>>[];
  final cell = 200 / n;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final x0 = (x * cell).round(), y0 = (y * cell).round(), x1 = ((x + 1) * cell).round(), y1 = ((y + 1) * cell).round();
      out.add([x0, y0, x1, y0, x1, y1, x0, y1]);
      final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, rr = cell * 0.34;
      final kind = (x + y + r.nextInt(2)) % 3;
      final pts = <int>[];
      final sides = kind == 0 ? 12 : (kind == 1 ? 4 : 3);
      final rot = kind == 1 ? math.pi / 4 : -math.pi / 2;
      for (var i = 0; i < sides; i++) {
        final a = rot + i * 2 * math.pi / sides;
        pts..add((cx + rr * math.cos(a)).round())..add((cy + rr * math.sin(a)).round());
      }
      out.add(pts);
    }
  }
  return out;
}

class BoyamaKind extends EgiticiKind {
  const BoyamaKind();
  @override
  String get id => 'boyama';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final t = d <= 3 ? 0 : r.nextInt(d <= 6 ? 3 : 4);
    if (t <= 1) {
      final pic = kPics[r.nextInt(kPics.length)];
      return ColorPuzzle([for (final reg in pic) List<int>.of(reg)], d <= 2 ? 8 : 12);
    }
    if (t == 2) return ColorPuzzle(mandala(r, 2 + d ~/ 3, 6 + 2 * (d ~/ 3)), 12);
    return ColorPuzzle(tiles(r, 3 + d ~/ 4), 12);
  }

  @override
  bool check(EPuzzle p) => p is ColorPuzzle && p.regions.length >= 3 && p.regions.every((g) => g.length >= 6 && g.length.isEven);

  @override
  Widget build(EPlay play) => _ColoringView(play: play, p: play.puzzle as ColorPuzzle);
}

class _ColoringView extends StatefulWidget {
  final EPlay play;
  final ColorPuzzle p;
  const _ColoringView({required this.play, required this.p});

  @override
  State<_ColoringView> createState() => _ColoringViewState();
}

class _ColoringViewState extends State<_ColoringView> with Clock<_ColoringView> {
  late List<int> fillOf; // -1 = boş
  int brush = 0;
  final List<(int, int)> history = [];

  @override
  void initState() {
    super.initState();
    fillOf = List<int>.filled(widget.p.regions.length, -1);
    startClock();
  }

  void _tap(Offset o) {
    if (ended) return;
    for (var i = widget.p.regions.length - 1; i >= 0; i--) {
      if (polyContains(widget.p.regions[i], o.dx, o.dy)) {
        if (fillOf[i] == brush) return;
        widget.play.sfx(Sfx.place);
        setState(() {
          history.add((i, fillOf[i]));
          fillOf[i] = brush;
        });
        if (fillOf.every((f) => f >= 0)) {
          ended = true;
          widget.play.sfx(Sfx.win);
          later(700, () => widget.play.finish(seconds: seconds));
        }
        return;
      }
    }
  }

  void _undo() {
    if (history.isEmpty || ended) return;
    setState(() {
      final h = history.removeLast();
      fillOf[h.$1] = h.$2;
    });
  }

  void _paint(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 200, 200), fill(Colors.white));
    for (var i = 0; i < widget.p.regions.length; i++) {
      final path = polyPath(widget.p.regions[i]);
      final f = fillOf[i];
      c.drawPath(path, fill(f < 0 ? Colors.white : Color(kArtPalette[f % kArtPalette.length])));
      c.drawPath(path, stroke(KColors.ink, 1.6));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = math.min<int>(widget.p.palette, kArtPalette.length);
    final done = fillOf.where((f) => f >= 0).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Expanded(child: LinearProgressIndicator(value: done / fillOf.length, minHeight: 10, borderRadius: BorderRadius.circular(5))),
          const SizedBox(width: 8),
          IconButton(tooltip: et(widget.play.lang, 'clear'), onPressed: history.isEmpty ? null : _undo, icon: const Icon(Icons.undo, size: 30)),
        ]),
      ),
      Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TapCanvas(w: 200, h: 200, paint: _paint, onTap: _tap))),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < n; i++)
            GestureDetector(
              onTap: () => setState(() => brush = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: brush == i ? 58 : 48,
                height: brush == i ? 58 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(kArtPalette[i]),
                  border: Border.all(color: brush == i ? KColors.ink : Colors.black26, width: brush == i ? 4 : 1.5),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- sayıyla boyama

class PixPuzzle extends EPuzzle {
  final int w;
  final int h;

  /// Hücre başına palet dizini (kArtPalette); 9 = beyaz arka plan (boyanmaz).
  final List<int> cells;
  const PixPuzzle(this.w, this.h, this.cells);

  List<int> get used {
    final s = <int>{};
    for (final c in cells) {
      if (c != 9) s.add(c);
    }
    return s.toList()..sort();
  }
}

PixPuzzle spriteFromArt(int i) {
  final rows = kPix[i % kPix.length];
  final cells = <int>[];
  for (final row in rows) {
    for (final ch in row.split('')) {
      final k = kPixKeys.indexOf(ch);
      cells.add(k < 0 ? 9 : kPixIndex[k]);
    }
  }
  return PixPuzzle(rows[0].length, rows.length, cells);
}

/// Simetrik, özgün küçük yaratık / süs deseni üretir.
PixPuzzle spriteRandom(SeededRandom r, int n, int colors) {
  final half = (n + 1) ~/ 2;
  var g = List<bool>.generate(n * n, (_) => false);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < half; x++) {
      final dc = (half - x) / half, dy = (y - n / 2).abs() / (n / 2);
      g[y * n + x] = r.nextDouble() < 0.75 - 0.35 * dc - 0.3 * dy;
    }
  }
  for (var pass = 0; pass < 2; pass++) {
    final ng = List<bool>.of(g);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < half; x++) {
        var c = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx, yy = y + dy;
            if (xx >= 0 && yy >= 0 && xx < half && yy < n && g[yy * n + xx]) c++;
          }
        }
        ng[y * n + x] = c >= 5 || (g[y * n + x] && c >= 4);
      }
    }
    g = ng;
  }
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < half; x++) {
      g[y * n + (n - 1 - x)] = g[y * n + x];
    }
  }
  final pal = <int>[0, 1, 2, 3, 4, 5, 6, 10, 11];
  r.shuffle(pal);
  final body = pal[0], edge = pal[1], spot = pal[2];
  final cells = List<int>.filled(n * n, 9);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (!g[y * n + x]) continue;
      var edgeCell = false;
      for (final dd in const [(0, -1), (1, 0), (0, 1), (-1, 0)]) {
        final xx = x + dd.$1, yy = y + dd.$2;
        if (xx < 0 || yy < 0 || xx >= n || yy >= n || !g[yy * n + xx]) edgeCell = true;
      }
      cells[y * n + x] = colors >= 2 && edgeCell ? edge : body;
    }
  }
  if (colors >= 3) {
    for (var y = 1; y < n - 1; y++) {
      for (var x = 1; x < half; x++) {
        if (cells[y * n + x] == body && r.chance(0.12)) {
          cells[y * n + x] = spot;
          cells[y * n + (n - 1 - x)] = spot;
        }
      }
    }
  }
  if (colors >= 4) {
    final ey = n ~/ 3, ex = n ~/ 2 - 2;
    if (ex >= 0 && cells[ey * n + ex] != 9) {
      cells[ey * n + ex] = 8;
      cells[ey * n + (n - 1 - ex)] = 8;
    }
  }
  return PixPuzzle(n, n, cells);
}

class SayiylaBoyamaKind extends EgiticiKind {
  const SayiylaBoyamaKind();
  @override
  String get id => 'sayiyla-boyama';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    if (d <= 3 || r.chance(0.4)) return spriteFromArt(r.nextInt(kPix.length));
    final n = clampI(6 + d, 8, 16);
    final p = spriteRandom(r, n, clampI(1 + d ~/ 2, 2, 4));
    return p;
  }

  @override
  bool check(EPuzzle p) {
    if (p is! PixPuzzle) return false;
    if (p.cells.length != p.w * p.h) return false;
    final filled = p.cells.where((c) => c != 9).length;
    if (filled < (p.w * p.h) ~/ 6) return false;
    final u = p.used;
    return u.isNotEmpty && u.length <= 8 && p.cells.every((c) => c >= 0 && c < kArtPalette.length);
  }

  @override
  Widget build(EPlay play) => _PixView(play: play, p: play.puzzle as PixPuzzle);
}

class _PixView extends StatefulWidget {
  final EPlay play;
  final PixPuzzle p;
  const _PixView({required this.play, required this.p});

  @override
  State<_PixView> createState() => _PixViewState();
}

class _PixViewState extends State<_PixView> with Clock<_PixView> {
  late final List<int> used = widget.p.used;
  late final List<bool> painted = [for (final c in widget.p.cells) c == 9];
  int brush = 0;
  int mistakes = 0;
  int lastWrong = -1;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  double get _cell => 200 / math.max<int>(widget.p.w, widget.p.h);

  void _at(Offset o) {
    if (ended) return;
    final x = (o.dx / _cell).floor(), y = (o.dy / _cell).floor();
    if (x < 0 || y < 0 || x >= widget.p.w || y >= widget.p.h) return;
    final i = y * widget.p.w + x;
    if (painted[i]) return;
    if (widget.p.cells[i] == used[brush]) {
      setState(() => painted[i] = true);
      widget.play.sfx(Sfx.tap);
      if (painted.every((b) => b)) {
        ended = true;
        widget.play.sfx(Sfx.win);
        later(700, () => widget.play.finish(mistakes: mistakes ~/ 3, seconds: seconds));
      }
    } else if (lastWrong != i) {
      lastWrong = i;
      mistakes++;
      widget.play.sfx(Sfx.error);
    }
  }

  void _paint(Canvas c) {
    final cs = _cell;
    c.drawRect(const Rect.fromLTWH(0, 0, 200, 200), fill(Colors.white));
    for (var y = 0; y < widget.p.h; y++) {
      for (var x = 0; x < widget.p.w; x++) {
        final i = y * widget.p.w + x;
        final r = Rect.fromLTWH(x * cs, y * cs, cs, cs);
        final v = widget.p.cells[i];
        if (v == 9) continue;
        if (painted[i]) {
          c.drawRect(r, fill(Color(kArtPalette[v])));
        } else {
          final k = used.indexOf(v);
          c.drawRect(r, fill(k == brush ? const Color(0xFFFFF4C2) : const Color(0xFFF4F1EA)));
          drawLabel(c, '${k + 1}', r.center, cs * 0.55, const Color(0xFF6B6B6B), weight: FontWeight.w600);
        }
        c.drawRect(r, stroke(const Color(0x22000000), 0.6));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = painted.where((b) => !b).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: LinearProgressIndicator(value: 1 - left / painted.length, minHeight: 10, borderRadius: BorderRadius.circular(5)),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TapCanvas(w: 200, h: 200, paint: _paint, onTap: _at, onPanStart: _at, onPanUpdate: _at),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < used.length; i++)
            GestureDetector(
              onTap: () => setState(() => brush = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: brush == i ? 62 : 52,
                height: brush == i ? 62 : 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(kArtPalette[used[i]]),
                  border: Border.all(color: brush == i ? KColors.ink : Colors.black26, width: brush == i ? 4 : 1.5),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: used[i] == 8 || used[i] == 4 || used[i] == 5 || used[i] == 7 ? Colors.white : KColors.ink,
                    )),
              ),
            ),
        ]),
      ),
    ]);
  }
}
