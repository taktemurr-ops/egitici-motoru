import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/alpha.dart';
import '../data/art.dart';
import '../data/turkey.dart';
import '../texts.dart';

// ---------------------------------------------------------------- Türkiye haritası yapbozu

const List<Color> _regionCols = [
  Color(0xFFF4A261),
  Color(0xFF8EC5E8),
  Color(0xFFF6C85F),
  Color(0xFFE9C46A),
  Color(0xFF7BC67E),
  Color(0xFFB8A1D9),
  Color(0xFFE07A5F),
];

class MapPuzzle extends EPuzzle {
  /// region < 0: 7 bölge parçası; yoksa o bölgenin illeri.
  final int region;

  /// Yerleştirilecek parçalar (bölge dizini ya da plaka), sırasıyla.
  final List<int> pieces;
  const MapPuzzle(this.region, this.pieces);
}

List<int> platesOf(int region) => [for (final p in kTurkey) if (p[2] == region) p[0] as int];

List<List<int>> ringsOfPlate(int plate) {
  for (final p in kTurkey) {
    if (p[0] == plate) return [for (final r in p.skip(3)) r as List<int>];
  }
  return const [];
}

String plateName(int plate) {
  for (final p in kTurkey) {
    if (p[0] == plate) return p[1] as String;
  }
  return '';
}

class TurkiyeKind extends EgiticiKind {
  const TurkiyeKind();
  @override
  String get id => 'turkiye-haritasi';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    if (d <= 3) {
      final ps = List<int>.generate(7, (i) => i);
      r.shuffle(ps);
      return MapPuzzle(-1, ps);
    }
    final reg = r.nextInt(7);
    final ps = platesOf(reg);
    r.shuffle(ps);
    final n = d <= 5 ? 6 : (d <= 7 ? 10 : ps.length);
    return MapPuzzle(reg, ps.take(math.min<int>(n, ps.length)).toList());
  }

  @override
  bool check(EPuzzle p) {
    if (p is! MapPuzzle || p.pieces.isEmpty) return false;
    if (p.pieces.toSet().length != p.pieces.length) return false;
    if (p.region < 0) return p.pieces.every((x) => x >= 0 && x < 7);
    final ok = platesOf(p.region).toSet();
    return p.region < 7 && p.pieces.every(ok.contains);
  }

  @override
  Widget build(EPlay play) => _MapView(play: play, p: play.puzzle as MapPuzzle);
}

class _MapView extends StatefulWidget {
  final EPlay play;
  final MapPuzzle p;
  const _MapView({required this.play, required this.p});

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> with Clock<_MapView> {
  int idx = 0;
  int mistakes = 0;
  final Set<int> placed = {};
  Offset? drag;
  late Rect view; // harita koordinatlarında görünen alan
  static const double cw = 1000, mapH = 470, trayH = 330;

  MapPuzzle get p => widget.p;

  @override
  void initState() {
    super.initState();
    startClock();
    if (p.region < 0) {
      view = Rect.fromLTWH(-10, -10, kTurkeyW + 20, kTurkeyH + 20);
    } else {
      final b = _bounds(platesOf(p.region));
      final pad = math.max(b.width, b.height) * 0.15;
      view = b.inflate(pad);
    }
  }

  List<List<int>> _pieceRings(int piece) {
    if (p.region < 0) return [for (final pl in platesOf(piece)) ...ringsOfPlate(pl)];
    return ringsOfPlate(piece);
  }

  Rect _bounds(List<int> plates) {
    var r = Rect.zero;
    var first = true;
    for (final pl in plates) {
      for (final ring in ringsOfPlate(pl)) {
        for (var i = 0; i + 1 < ring.length; i += 2) {
          final pt = Rect.fromLTWH(ring[i].toDouble(), ring[i + 1].toDouble(), 0, 0);
          r = first ? pt : r.expandToInclude(pt);
          first = false;
        }
      }
    }
    return r;
  }

  Rect _pieceBounds(int piece) => _bounds(p.region < 0 ? platesOf(piece) : [piece]);

  /// harita → tuval (üstteki harita alanı)
  double get k => math.min(cw / view.width, mapH / view.height);
  Offset get o0 => Offset((cw - view.width * k) / 2 - view.left * k, (mapH - view.height * k) / 2 - view.top * k);
  Offset toC(double x, double y) => Offset(x, y) * k + o0;

  Path _path(List<List<int>> rings, double sk, Offset off) {
    final path = Path();
    for (final ring in rings) {
      path.addPath(polyPath(ring, sx: sk, sy: sk), off);
    }
    return path;
  }

  int get current => p.pieces[idx];

  Offset get targetC {
    final b = _pieceBounds(current);
    return toC(b.center.dx, b.center.dy);
  }

  double get trayScale {
    final b = _pieceBounds(current);
    return math.min(260 / math.max(b.width * k, b.height * k), 2.6) * k;
  }

  Offset get trayC => const Offset(cw / 2, mapH + trayH / 2);

  void _start(Offset o) {
    if (ended) return;
    if ((o - trayC).distance < 170) setState(() => drag = o);
  }

  void _move(Offset o) {
    if (drag != null) setState(() => drag = o);
  }

  void _drop() {
    final d = drag;
    if (d == null) return;
    final b = _pieceBounds(current);
    final tol = math.max(34.0, math.max(b.width, b.height) * k * 0.35);
    if ((d - targetC).distance <= tol) {
      widget.play.sfx(Sfx.place);
      widget.play.answer(true);
      setState(() {
        placed.add(current);
        drag = null;
        if (idx + 1 >= p.pieces.length) {
          ended = true;
          later(800, () => widget.play.finish(mistakes: mistakes, seconds: seconds));
        } else {
          idx++;
        }
      });
    } else {
      widget.play.sfx(Sfx.error);
      widget.play.answer(false);
      setState(() {
        mistakes++;
        drag = null;
      });
    }
  }

  String _label(int piece) => p.region < 0 ? pickL(kRegionNames[piece], widget.play.lang) : plateName(piece);

  void _paint(Canvas c) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, cw, mapH), const Radius.circular(24)), fill(const Color(0xFFDDEEF8)));
    // bütün iller (bağlam)
    for (final pr in kTurkey) {
      final plate = pr[0] as int, reg = pr[2] as int;
      final rings = [for (final r in pr.skip(3)) r as List<int>];
      final path = _path(rings, k, o0);
      final inPuzzle = p.region < 0 || reg == p.region;
      final isPiece = p.region < 0 ? true : p.pieces.contains(plate);
      final done = p.region < 0 ? placed.contains(reg) : (placed.contains(plate) || (inPuzzle && !isPiece));
      Color col;
      if (!inPuzzle) {
        col = const Color(0xFFEFEAE0);
      } else if (done) {
        col = _regionCols[reg % 7];
      } else {
        col = Colors.white;
      }
      c.drawPath(path, fill(col));
      c.drawPath(path, stroke(inPuzzle ? const Color(0xFF9A8F7C) : const Color(0xFFD5CDBE), inPuzzle ? 1.4 : 0.8));
    }
    // yerleşen parçaların adları
    for (final pc in placed) {
      final b = _pieceBounds(pc);
      final at = toC(b.center.dx, b.center.dy);
      drawLabel(c, _label(pc), at, p.region < 0 ? 22 : 15, KColors.ink);
    }
    if (ended) return;
    // tepsi
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cw * 0.2, mapH + 14, cw * 0.6, trayH - 28), const Radius.circular(28)), fill(const Color(0xFFFFF4DA)));
    final b = _pieceBounds(current);
    final d = drag;
    final sk = d == null ? trayScale : k;
    final center = d ?? trayC;
    final off = center - Offset(b.center.dx * sk, b.center.dy * sk);
    final path = _path(_pieceRings(current), sk, off);
    c.drawPath(path, fill(_regionCols[(p.region < 0 ? current : p.region) % 7]));
    c.drawPath(path, stroke(KColors.ink, 2));
    if (d == null) drawLabel(c, _label(current), Offset(cw / 2, mapH + trayH - 40), 26, KColors.ink);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: StepDots(done: placed.length, total: p.pieces.length)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TapCanvas(w: cw, h: mapH + trayH, paint: _paint, onPanStart: _start, onPanUpdate: _move, onPanEnd: _drop),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- blok kodlama

class CodePuzzle extends EPuzzle {
  final int w;
  final int h;
  final int start;
  final int goal;
  final List<int> walls;
  final List<int> flowers;

  /// En kısa çözümün komut sayısı (tekrarlar sıkıştırılmış).
  final int par;
  final bool repeats;
  const CodePuzzle(this.w, this.h, this.start, this.goal, this.walls, this.flowers, this.par, this.repeats);
}

const List<(int, int)> _dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)];
const List<IconData> _dirIcons = [Icons.arrow_upward_rounded, Icons.arrow_forward_rounded, Icons.arrow_downward_rounded, Icons.arrow_back_rounded];

/// (pos, toplanan çiçek maskesi) üzerinde BFS; en kısa yön dizisi ya da null.
List<int>? solveCode(int w, int h, int start, int goal, Set<int> walls, List<int> flowers) {
  final full = (1 << flowers.length) - 1;
  final startMask = flowers.indexOf(start) >= 0 ? 1 << flowers.indexOf(start) : 0;
  final prev = <int, (int, int)>{};
  final q = <int>[start * 64 + startMask];
  prev[q.first] = (-1, -1);
  var head = 0;
  while (head < q.length) {
    final s = q[head++];
    final pos = s ~/ 64, mask = s % 64;
    if (pos == goal && mask == full) {
      final out = <int>[];
      var cur = s;
      while (prev[cur]!.$1 >= 0) {
        out.add(prev[cur]!.$2);
        cur = prev[cur]!.$1;
      }
      return out.reversed.toList();
    }
    final x = pos % w, y = pos ~/ w;
    for (var d = 0; d < 4; d++) {
      final nx = x + _dirs[d].$1, ny = y + _dirs[d].$2;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final np = ny * w + nx;
      if (walls.contains(np)) continue;
      final fi = flowers.indexOf(np);
      final nm = fi >= 0 ? mask | (1 << fi) : mask;
      final ns = np * 64 + nm;
      if (prev.containsKey(ns)) continue;
      prev[ns] = (s, d);
      q.add(ns);
    }
  }
  return null;
}

int runsOf(List<int> moves, bool repeats) {
  if (moves.isEmpty) return 0;
  var n = 0;
  var i = 0;
  while (i < moves.length) {
    var j = i;
    while (j < moves.length && moves[j] == moves[i] && (repeats ? j - i < 3 : j - i < 1)) {
      j++;
    }
    n++;
    i = j;
  }
  return n;
}

class KodlamaKind extends EgiticiKind {
  const KodlamaKind();
  @override
  String get id => 'kodlama';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final n = d <= 2 ? 4 : (d <= 4 ? 5 : (d <= 7 ? 6 : 7));
    final cells = n * n;
    final start = r.nextInt(cells);
    var goal = r.nextInt(cells);
    var g = 0;
    while ((goal == start || ((goal % n - start % n).abs() + (goal ~/ n - start ~/ n).abs()) < 2 + d ~/ 3) && g++ < 50) {
      goal = r.nextInt(cells);
    }
    final walls = <int>{};
    final wn = (cells * (0.08 + d * 0.018)).round();
    while (walls.length < wn) {
      final c = r.nextInt(cells);
      if (c != start && c != goal) walls.add(c);
    }
    final flowers = <int>[];
    final fn = d >= 5 ? (d >= 8 ? 2 : 1) : 0;
    g = 0;
    while (flowers.length < fn && g++ < 50) {
      final c = r.nextInt(cells);
      if (c != start && c != goal && !walls.contains(c) && !flowers.contains(c)) flowers.add(c);
    }
    final sol = solveCode(n, n, start, goal, walls, flowers);
    if (sol == null || sol.length < 2 || sol.length > 18) return null;
    final repeats = d >= 6;
    final par = runsOf(sol, repeats);
    if (par > 10) return null;
    return CodePuzzle(n, n, start, goal, walls.toList()..sort(), flowers, par, repeats);
  }

  @override
  bool check(EPuzzle p) {
    if (p is! CodePuzzle) return false;
    final sol = solveCode(p.w, p.h, p.start, p.goal, p.walls.toSet(), p.flowers);
    return sol != null && sol.length >= 2 && runsOf(sol, p.repeats) == p.par;
  }

  @override
  Widget build(EPlay play) => _CodeView(play: play, p: play.puzzle as CodePuzzle);
}

class _CodeView extends StatefulWidget {
  final EPlay play;
  final CodePuzzle p;
  const _CodeView({required this.play, required this.p});

  @override
  State<_CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<_CodeView> with Clock<_CodeView> {
  final List<(int, int)> prog = []; // (yön, tekrar)
  int pos = 0;
  final Set<int> got = {};
  bool running = false;
  bool bump = false;
  int mistakes = 0;
  int step = -1;

  CodePuzzle get p => widget.p;

  @override
  void initState() {
    super.initState();
    pos = p.start;
    startClock();
  }

  void _add(int d) {
    if (running || prog.length >= 10) return;
    widget.play.sfx(Sfx.tap);
    setState(() => prog.add((d, 1)));
  }

  void _cycle(int i) {
    if (running || !p.repeats) return;
    setState(() => prog[i] = (prog[i].$1, prog[i].$2 % 3 + 1));
  }

  void _run() {
    if (running || prog.isEmpty) return;
    final moves = <(int, int)>[];
    for (var i = 0; i < prog.length; i++) {
      for (var k = 0; k < prog[i].$2; k++) {
        moves.add((prog[i].$1, i));
      }
    }
    setState(() {
      running = true;
      pos = p.start;
      got.clear();
      bump = false;
    });
    var cur = p.start;
    final walls = p.walls.toSet();
    var t = 0;
    var failed = false;
    for (final m in moves) {
      final x = cur % p.w + _dirs[m.$1].$1, y = cur ~/ p.w + _dirs[m.$1].$2;
      t++;
      if (x < 0 || y < 0 || x >= p.w || y >= p.h || walls.contains(y * p.w + x)) {
        failed = true;
        final at = t;
        later(at * 420, () => setState(() {
              bump = true;
              step = m.$2;
            }));
        break;
      }
      cur = y * p.w + x;
      final c2 = cur, at = t;
      later(at * 420, () {
        widget.play.sfx(Sfx.tap);
        setState(() {
          pos = c2;
          step = m.$2;
          if (p.flowers.contains(c2)) got.add(c2);
        });
      });
    }
    final success = !failed && cur == p.goal && p.flowers.every((f) => _visits(moves, f));
    later((t + 1) * 420 + 200, () {
      if (success) {
        ended = true;
        widget.play.sfx(Sfx.win);
        widget.play.answer(true);
        widget.play.finish(mistakes: mistakes, seconds: seconds);
      } else {
        widget.play.sfx(Sfx.error);
        widget.play.answer(false);
        setState(() {
          mistakes++;
          running = false;
          pos = p.start;
          got.clear();
          step = -1;
        });
      }
    });
  }

  bool _visits(List<(int, int)> moves, int cell) {
    var cur = p.start;
    if (cur == cell) return true;
    for (final m in moves) {
      cur = (cur ~/ p.w + _dirs[m.$1].$2) * p.w + cur % p.w + _dirs[m.$1].$1;
      if (cur == cell) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return Column(children: [
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final cs = box.maxWidth / p.w;
              return Stack(children: [
                for (var i = 0; i < p.w * p.h; i++)
                  Positioned(
                    left: (i % p.w) * cs,
                    top: (i ~/ p.w) * cs,
                    width: cs,
                    height: cs,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: p.walls.contains(i) ? const Color(0xFF7FA36B) : ((i % p.w + i ~/ p.w).isEven ? const Color(0xFFF7F1E3) : const Color(0xFFEFE7D4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.walls.contains(i) ? '🌳' : (i == p.goal ? '🏠' : (p.flowers.contains(i) && !got.contains(i) ? '🌼' : '')),
                        style: TextStyle(fontSize: cs * 0.55),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  left: (pos % p.w) * cs,
                  top: (pos ~/ p.w) * cs,
                  width: cs,
                  height: cs,
                  child: Center(child: Text(bump ? '😵' : '🐝', style: TextStyle(fontSize: cs * 0.6))),
                ),
              ]);
            }),
          ),
        ),
      ),
      SizedBox(
        height: 70,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          for (var i = 0; i < prog.length; i++)
            GestureDetector(
              onTap: () => _cycle(i),
              onLongPress: running ? null : () => setState(() => prog.removeAt(i)),
              child: Container(
                width: 60,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: step == i ? const Color(0xFFCDEBD3) : KColors.tiles[prog[i].$1 % KColors.tiles.length],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(_dirIcons[prog[i].$1], size: 34),
                  if (prog[i].$2 > 1) Positioned(right: 4, bottom: 2, child: Text('×${prog[i].$2}', style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var d = 0; d < 4; d++) Padding(padding: const EdgeInsets.all(4), child: BigButton(size: 60, onTap: () => _add(d), child: Icon(_dirIcons[d], size: 32))),
          const SizedBox(width: 10),
          BigButton(
            size: 60,
            color: KColors.soft,
            tooltip: et(lang, 'clear'),
            onTap: running ? null : () => setState(() => prog.clear()),
            child: const Icon(Icons.backspace_outlined),
          ),
          const SizedBox(width: 6),
          BigButton(size: 68, color: const Color(0xFFCDEBD3), tooltip: et(lang, 'run'), onTap: _run, child: const Icon(Icons.play_arrow_rounded, size: 40)),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- labirent ve yapboz

class LabPuzzle extends EPuzzle {
  /// 0 labirent, 1 resim yapbozu.
  final int mode;
  final int w;
  final int h;

  /// Labirentte hücre başına açık kenar bitleri (1 üst, 2 sağ, 4 alt, 8 sol);
  /// yapbozda karo sırası (karışık).
  final List<int> data;
  final int pic;
  const LabPuzzle(this.mode, this.w, this.h, this.data, this.pic);
}

List<int> carveMaze(SeededRandom r, int w, int h) {
  final open = List<int>.filled(w * h, 0);
  final seen = List<bool>.filled(w * h, false);
  final stack = <int>[0];
  seen[0] = true;
  const bits = [1, 2, 4, 8], back = [4, 8, 1, 2];
  while (stack.isNotEmpty) {
    final c = stack.last;
    final x = c % w, y = c ~/ w;
    final opts = <int>[];
    for (var d = 0; d < 4; d++) {
      final nx = x + _dirs[d].$1, ny = y + _dirs[d].$2;
      if (nx >= 0 && ny >= 0 && nx < w && ny < h && !seen[ny * w + nx]) opts.add(d);
    }
    if (opts.isEmpty) {
      stack.removeLast();
      continue;
    }
    final d = r.pick(opts);
    final n = (y + _dirs[d].$2) * w + x + _dirs[d].$1;
    open[c] |= bits[d];
    open[n] |= back[d];
    seen[n] = true;
    stack.add(n);
  }
  return open;
}

bool mazeConnected(int w, int h, List<int> open) {
  final seen = <int>{0};
  final q = <int>[0];
  const bits = [1, 2, 4, 8];
  while (q.isNotEmpty) {
    final c = q.removeLast();
    for (var d = 0; d < 4; d++) {
      if (open[c] & bits[d] == 0) continue;
      final nx = c % w + _dirs[d].$1, ny = c ~/ w + _dirs[d].$2;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) return false;
      if (seen.add(ny * w + nx)) q.add(ny * w + nx);
    }
  }
  return seen.length == w * h;
}

class LabirentKind extends EgiticiKind {
  const LabirentKind();
  @override
  String get id => 'labirent-yapboz';

  @override
  EPuzzle? make(int d, SeededRandom r) {
    if (r.chance(0.5)) {
      final w = 3 + d ~/ 2 + 1, h = 4 + d ~/ 2 + 1;
      return LabPuzzle(0, w, h, carveMaze(r, w, h), 0);
    }
    final n = d <= 2 ? 2 : (d <= 5 ? 3 : 4);
    final perm = List<int>.generate(n * n, (i) => i);
    var g = 0;
    do {
      r.shuffle(perm);
    } while (_sorted(perm) && g++ < 10);
    if (_sorted(perm)) return null;
    return LabPuzzle(1, n, n, perm, r.nextInt(kPics.length));
  }

  static bool _sorted(List<int> p) {
    for (var i = 0; i < p.length; i++) {
      if (p[i] != i) return false;
    }
    return true;
  }

  @override
  bool check(EPuzzle p) {
    if (p is! LabPuzzle || p.data.length != p.w * p.h) return false;
    if (p.mode == 0) return p.w >= 3 && p.h >= 3 && mazeConnected(p.w, p.h, p.data);
    return !_sorted(p.data) && p.data.toSet().length == p.data.length && p.pic >= 0 && p.pic < kPics.length;
  }

  @override
  Widget build(EPlay play) {
    final p = play.puzzle as LabPuzzle;
    return p.mode == 0 ? _MazeView(play: play, p: p) : _SwapView(play: play, p: p);
  }
}

class _MazeView extends StatefulWidget {
  final EPlay play;
  final LabPuzzle p;
  const _MazeView({required this.play, required this.p});

  @override
  State<_MazeView> createState() => _MazeViewState();
}

class _MazeViewState extends State<_MazeView> with Clock<_MazeView> {
  final List<int> path = [0];
  static const double cell = 60;

  LabPuzzle get p => widget.p;
  int get goal => p.w * p.h - 1;

  @override
  void initState() {
    super.initState();
    startClock();
  }

  void _at(Offset o) {
    if (ended) return;
    final x = (o.dx / cell).floor(), y = (o.dy / cell).floor();
    if (x < 0 || y < 0 || x >= p.w || y >= p.h) return;
    final c = y * p.w + x;
    final last = path.last;
    if (c == last) return;
    if (path.length >= 2 && c == path[path.length - 2]) {
      setState(() => path.removeLast());
      return;
    }
    final lx = last % p.w, ly = last ~/ p.w;
    for (var d = 0; d < 4; d++) {
      if (lx + _dirs[d].$1 == x && ly + _dirs[d].$2 == y && p.data[last] & const [1, 2, 4, 8][d] != 0) {
        if (path.contains(c)) return;
        widget.play.sfx(Sfx.tap);
        setState(() => path.add(c));
        if (c == goal) {
          ended = true;
          widget.play.sfx(Sfx.win);
          later(600, () => widget.play.finish(seconds: seconds));
        }
        return;
      }
    }
  }

  void _paint(Canvas c) {
    final ww = p.w * cell, hh = p.h * cell;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, ww, hh), const Radius.circular(16)), fill(const Color(0xFFF7F1E3)));
    if (path.length >= 2) {
      final pp = Path();
      for (var i = 0; i < path.length; i++) {
        final o = Offset((path[i] % p.w + 0.5) * cell, (path[i] ~/ p.w + 0.5) * cell);
        if (i == 0) {
          pp.moveTo(o.dx, o.dy);
        } else {
          pp.lineTo(o.dx, o.dy);
        }
      }
      c.drawPath(pp, stroke(const Color(0xFF8EC5E8), cell * 0.36));
    }
    final wall = stroke(const Color(0xFF6B5B45), 5);
    for (var i = 0; i < p.w * p.h; i++) {
      final x = (i % p.w) * cell, y = (i ~/ p.w) * cell;
      final o = p.data[i];
      if (o & 1 == 0) c.drawLine(Offset(x, y), Offset(x + cell, y), wall);
      if (o & 2 == 0) c.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), wall);
      if (o & 4 == 0) c.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), wall);
      if (o & 8 == 0) c.drawLine(Offset(x, y), Offset(x, y + cell), wall);
    }
    drawLabel(c, '🧀', Offset((p.w - 0.5) * cell, (p.h - 0.5) * cell), cell * 0.6, KColors.ink);
    final me = path.last;
    drawLabel(c, '🐭', Offset((me % p.w + 0.5) * cell, (me ~/ p.w + 0.5) * cell), cell * 0.62, KColors.ink);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: TapCanvas(w: p.w * cell, h: p.h * cell, paint: _paint, onPanStart: _at, onPanUpdate: _at, onTap: _at),
      );
}

class _SwapView extends StatefulWidget {
  final EPlay play;
  final LabPuzzle p;
  const _SwapView({required this.play, required this.p});

  @override
  State<_SwapView> createState() => _SwapViewState();
}

class _SwapViewState extends State<_SwapView> with Clock<_SwapView> {
  late List<int> order = List<int>.of(widget.p.data);
  int? sel;
  int swaps = 0;
  late final int minSwaps;
  late final List<int> regionCol;

  @override
  void initState() {
    super.initState();
    startClock();
    final seen = List<bool>.filled(order.length, false);
    var cycles = 0;
    for (var i = 0; i < order.length; i++) {
      if (seen[i]) continue;
      cycles++;
      var j = i;
      while (!seen[j]) {
        seen[j] = true;
        j = order[j];
      }
    }
    minSwaps = order.length - cycles;
    final regs = kPics[widget.p.pic];
    regionCol = [for (var i = 0; i < regs.length; i++) const [0, 1, 2, 3, 4, 5, 6, 10, 11][(i * 5 + widget.p.pic) % 9]];
  }

  void _tap(Offset o) {
    if (ended) return;
    final n = widget.p.w;
    final cs = 200 / n;
    final x = (o.dx / cs).floor(), y = (o.dy / cs).floor();
    if (x < 0 || y < 0 || x >= n || y >= n) return;
    final i = y * n + x;
    final s = sel;
    if (s == null) {
      setState(() => sel = i);
      return;
    }
    if (s == i) {
      setState(() => sel = null);
      return;
    }
    widget.play.sfx(Sfx.place);
    setState(() {
      final t = order[s];
      order[s] = order[i];
      order[i] = t;
      sel = null;
      swaps++;
    });
    if (LabirentKind._sorted(order)) {
      ended = true;
      widget.play.sfx(Sfx.win);
      later(700, () => widget.play.finish(mistakes: math.max<int>(0, swaps - minSwaps) ~/ 2, seconds: seconds));
    }
  }

  void _drawPic(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 200, 200), fill(const Color(0xFFFDF8EE)));
    final regs = kPics[widget.p.pic];
    for (var i = 0; i < regs.length; i++) {
      final path = polyPath(regs[i]);
      c.drawPath(path, fill(Color(kArtPalette[regionCol[i] % kArtPalette.length])));
      c.drawPath(path, stroke(KColors.ink, 1.4));
    }
  }

  void _paint(Canvas c) {
    final n = widget.p.w;
    final cs = 200 / n;
    for (var i = 0; i < order.length; i++) {
      final src = order[i];
      final sx = (src % n) * cs, sy = (src ~/ n) * cs;
      final dx = (i % n) * cs, dy = (i ~/ n) * cs;
      c.save();
      c.clipRect(Rect.fromLTWH(dx, dy, cs, cs));
      c.translate(dx - sx, dy - sy);
      _drawPic(c);
      c.restore();
      c.drawRect(Rect.fromLTWH(dx, dy, cs, cs), stroke(sel == i ? KColors.accent : Colors.white, sel == i ? 4 : 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 90, height: 90, child: TapCanvas(w: 200, h: 200, paint: _drawPic)),
          const SizedBox(width: 12),
          Flexible(
            child: Text('${et(lang, 'progress')}: ${order.asMap().entries.where((e) => e.key == e.value).length}/${order.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      Expanded(child: Padding(padding: const EdgeInsets.all(10), child: TapCanvas(w: 200, h: 200, paint: _paint, onTap: _tap))),
      const SizedBox(height: 4),
    ]);
  }
}
