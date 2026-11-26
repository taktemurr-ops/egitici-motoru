import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../data/alpha.dart';
import '../data/misc.dart';
import '../kid/quiz.dart';
import '../kid/vis.dart';
import '../texts.dart';
import 'quizzes.dart';

/// Ses dosyası adları (hub: assets/sfx/note_*.wav). 0 = do4 … 14 = do6.
const List<String> kNoteFiles = ['c4', 'd4', 'e4', 'f4', 'g4', 'a4', 'b4', 'c5', 'd5', 'e5', 'f5', 'g5', 'a5', 'b5', 'c6'];

const List<Color> _keyCols = [
  Color(0xFFF6B5B5),
  Color(0xFFF8CFA0),
  Color(0xFFF7E59B),
  Color(0xFFC7E8B5),
  Color(0xFFB5DDF0),
  Color(0xFFC9C3F0),
  Color(0xFFEEC3E6),
];

// ---------------------------------------------------------------- çocuk piyanosu

class PianoPuzzle extends EPuzzle {
  /// 0: şarkı takibi (yanan tuşa bas); 1: yankı (dinle ve tekrarla).
  final int mode;
  final int keys;
  final List<List<int>> phrases;
  const PianoPuzzle(this.mode, this.keys, this.phrases);
}

class PiyanoKind extends EgiticiKind {
  const PiyanoKind();
  @override
  String get id => 'piyano';

  List<int> _melody(SeededRandom r, int len, int keys) {
    const scale = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14];
    final pool = [for (final s in scale) if (s < keys) s];
    var cur = r.nextInt(math.min<int>(pool.length, 5));
    final out = <int>[pool[cur]];
    while (out.length < len) {
      cur = clampI(cur + r.range(-2, 2), 0, pool.length - 1);
      out.add(pool[cur]);
    }
    return out;
  }

  @override
  EPuzzle? make(int d, SeededRandom r) {
    final keys = d <= 4 ? 8 : 15;
    final echo = d >= 4 && r.chance(0.5);
    if (echo) {
      final n = 3 + d ~/ 3;
      return PianoPuzzle(1, keys, [for (var i = 0; i < n; i++) _melody(r, 2 + i ~/ 2 + d ~/ 4, d <= 6 ? 8 : keys)]);
    }
    final songs = [for (final s in kSongs) if (s.every((n) => n < keys)) s];
    if (d <= 6 || r.chance(0.6)) {
      final a = r.nextInt(songs.length);
      final b = (a + 1 + r.nextInt(songs.length - 1)) % songs.length;
      return PianoPuzzle(0, keys, d <= 2 ? [songs[a]] : [songs[a], songs[b]]);
    }
    return PianoPuzzle(0, keys, [_melody(r, 10 + d, keys), _melody(r, 10 + d, keys)]);
  }

  @override
  bool check(EPuzzle p) =>
      p is PianoPuzzle && p.phrases.isNotEmpty && p.phrases.every((ph) => ph.length >= 2 && ph.every((n) => n >= 0 && n < p.keys)) && (p.keys == 8 || p.keys == 15);

  @override
  Widget build(EPlay play) => _PianoView(play: play, p: play.puzzle as PianoPuzzle);
}

class _PianoView extends StatefulWidget {
  final EPlay play;
  final PianoPuzzle p;
  const _PianoView({required this.play, required this.p});

  @override
  State<_PianoView> createState() => _PianoViewState();
}

class _PianoViewState extends State<_PianoView> with Clock<_PianoView> {
  int phrase = 0;
  int pos = 0;
  int mistakes = 0;
  int? lit;
  bool demo = false;
  bool free = false;

  PianoPuzzle get p => widget.p;
  List<int> get cur => p.phrases[phrase];

  @override
  void initState() {
    super.initState();
    startClock();
    if (p.mode == 1) later(600, _demo);
  }

  void _demo() {
    if (ended) return;
    setState(() {
      demo = true;
      pos = 0;
    });
    for (var i = 0; i < cur.length; i++) {
      later(i * 650, () {
        widget.play.sound('note_${kNoteFiles[cur[i]]}');
        setState(() => lit = cur[i]);
      });
    }
    later(cur.length * 650, () => setState(() {
          demo = false;
          lit = null;
        }));
  }

  void _press(int k) {
    widget.play.sound('note_${kNoteFiles[k]}');
    setState(() => lit = k);
    later(220, () {
      if (lit == k) setState(() => lit = null);
    });
    if (free || ended || demo) return;
    if (k == cur[pos]) {
      pos++;
      if (pos >= cur.length) {
        if (phrase + 1 >= p.phrases.length) {
          ended = true;
          later(500, () => widget.play.finish(mistakes: mistakes ~/ 2, seconds: seconds));
        } else {
          later(700, () {
            setState(() {
              phrase++;
              pos = 0;
            });
            if (p.mode == 1) _demo();
          });
        }
      }
      setState(() {});
    } else {
      mistakes++;
      if (p.mode == 1) later(500, _demo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.play.lang;
    final names = kNoteNames[lang] ?? kNoteNames['en']!;
    final next = !free && !demo && !ended && p.mode == 0 && pos < cur.length ? cur[pos] : -1;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(child: StepDots(done: phrase, total: p.phrases.length)),
          if (p.mode == 1)
            IconButton(tooltip: et(lang, 'listen'), onPressed: demo ? null : _demo, icon: const Icon(Icons.hearing, size: 32)),
          FilterChip(
            label: Text(et(lang, 'free')),
            selected: free,
            onSelected: (v) => setState(() => free = v),
          ),
        ]),
      ),
      SizedBox(
        height: 70,
        child: Center(
          child: Wrap(spacing: 4, children: [
            for (var i = 0; i < cur.length; i++)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pos ? _keyCols[cur[i] % 7] : const Color(0xFFEDE6D8),
                  border: Border.all(color: Colors.black12),
                ),
              ),
          ]),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var k = 0; k < p.keys; k++)
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => _press(k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: lit == k ? _keyCols[k % 7] : (next == k ? Color.lerp(Colors.white, _keyCols[k % 7], 0.75) : Colors.white),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      border: Border.all(color: next == k ? KColors.ink : Colors.black26, width: next == k ? 3 : 1),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (next == k) const Text('⬇️', style: TextStyle(fontSize: 22)),
                      const SizedBox(height: 6),
                      Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: _keyCols[k % 7])),
                      const SizedBox(height: 4),
                      FittedBox(child: Text(names[k % 7], style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.ink))),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- nota öğrenme

class NotaKind extends QuizKind {
  const NotaKind();
  @override
  String get id => 'nota';

  @override
  QItem? item(int d, SeededRandom r, int k) {
    final hi = d <= 3 ? 5 : (d <= 6 ? 8 : 15);
    final note = r.nextInt(hi);
    final n = optCount(d);
    if (d >= 4 && r.chance(0.4)) {
      final others = <int>[];
      var g = 0;
      while (others.length < n - 1 && g++ < 100) {
        final o = r.nextInt(hi);
        if (o % 7 != note % 7 && !others.any((x) => x % 7 == o % 7)) others.add(o);
      }
      return qi(Vis(VT.note, a: note % 7), Vis(VT.staff, a: note), [for (final o in others) Vis(VT.staff, a: o)], r, sound: 'note_${kNoteFiles[note]}');
    }
    final names = distinct(r, 7, n - 1, avoid: {note % 7});
    return qi(Vis(VT.staff, a: note), Vis(VT.note, a: note % 7), [for (final o in names) Vis(VT.note, a: o)], r, sound: 'note_${kNoteFiles[note]}');
  }
}
