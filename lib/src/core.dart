import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';
import 'package:studio_core/core/strings.dart';

import 'kid/frame.dart';
import 'kid/store.dart';
import 'studio_chrome.dart';

/// Eğitici oyunlardan birinin kurulmuş bölümü.
abstract class EPuzzle {
  const EPuzzle();
}

class ELevel {
  final String kind;
  final int d;
  final EPuzzle puzzle;
  const ELevel(this.kind, this.d, this.puzzle);
}

/// Eğitici oyun türü: bölüm üretir, bölümü denetler, ekranı kurar.
abstract class EgiticiKind {
  const EgiticiKind();
  String get id;

  /// Zorluk 1..10 için deterministik bölüm (kurulamazsa null).
  EPuzzle? make(int d, SeededRandom r);

  /// Bölümün kurallara uyduğunu (çözülebilir, seçenekler ayrık…) denetler.
  bool check(EPuzzle p);

  Widget build(EPlay play);

  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Tamamlanan bölüm', 'Levels completed', scale: 10),
        GameStat('perfect', 'Hatasız bölüm', 'Perfect levels', scale: 10),
      ];

  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('perfect', 'perfect', [1, 5, 15]),
      ];
}

EPuzzle realizeEgitici(EgiticiKind k, int d, int seed) {
  for (var dd = d; dd >= 1; dd--) {
    for (var a = 0; a < 25; a++) {
      EPuzzle? p;
      try {
        p = k.make(dd, SeededRandom(mixSeed([seed, a, dd, 4421])));
      } catch (_) {
        p = null;
      }
      if (p != null && k.check(p)) return p;
    }
  }
  throw StateError('eğitici bölüm kurulamadı: ${k.id} $d');
}

class EgiticiRules extends GameRules<ELevel> {
  @override
  final String gameId;
  final EgiticiKind kind;
  final int levels;
  EgiticiRules({required this.gameId, required this.kind, this.levels = 100000});

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily];

  @override
  List<GameStat> get gameStats => kind.stats;

  @override
  List<MissionTemplate> get missionTemplates => kind.missions;

  @override
  ELevel generate(LevelSpec spec) {
    final d = clampI(spec.difficulty, 1, 10);
    return ELevel(kind.id, d, realizeEgitici(kind, d, spec.seed));
  }

  @override
  Validation validate(ELevel puzzle, LevelSpec spec) =>
      puzzle.kind == kind.id && kind.check(puzzle.puzzle) ? const Validation.ok() : const Validation.fail('invalid');
}

/// Bölüm boyunca oyun ekranının kabuğa erişimi.
class EPlay {
  final PlayContext ctx;
  final EPuzzle puzzle;
  final String gameId;
  final int d;
  final int seed;
  final KidHooks hooks;
  EPlay({required this.ctx, required this.puzzle, required this.gameId, required this.d, required this.seed, required this.hooks});

  String get lang => ctx.lang;

  bool get rtl => const ['ar', 'fa', 'he', 'ur'].contains(ctx.lang);

  void sfx(Sfx s) => ctx.sfx(s);

  void sound(String name) => ctx.sound(name);

  /// Yerel istatistik (ebeveyn raporu): doğru / yanlış cevap.
  void answer(bool correct) => KidStore.instance.answer(gameId, correct);

  bool _done = false;

  /// Çocuk oyunlarında kaybetmek yok: bölüm biter, yıldız hatalara göre.
  void finish({int mistakes = 0, int seconds = 0, int score = 0}) {
    if (_done) return;
    _done = true;
    final stars = mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : 1);
    KidStore.instance.levelDone(gameId, seconds);
    final sticker = KidStore.instance.awardSticker(mixSeed([seed, gameId.length, d]));
    hooks.celebrate(sticker, () {
      ctx.finish(RoundResult(
        won: true,
        score: score > 0 ? score : 100 * stars,
        stars: stars,
        seconds: seconds,
        gameStats: {'rounds_won': 1, if (mistakes == 0) 'perfect': 1},
      ));
    });
  }
}

/// Eğitici oyunların ortak sahnesi: çocuk çerçevesi (çıkartma albümü,
/// ebeveyn alanı, süre sınırı) içinde türün ekranı.
class EgiticiStage extends StatefulWidget {
  final PlayContext ctx;
  final EgiticiRules rules;
  const EgiticiStage({super.key, required this.ctx, required this.rules});

  @override
  State<EgiticiStage> createState() => _EgiticiStageState();
}

class _EgiticiStageState extends State<EgiticiStage> {
  final hooks = KidHooks();
  late final EPlay play;

  @override
  void initState() {
    super.initState();
    final lv = widget.ctx.generated.puzzle as ELevel;
    play = EPlay(ctx: widget.ctx, puzzle: lv.puzzle, gameId: widget.rules.gameId, d: lv.d, seed: widget.ctx.spec.seed, hooks: hooks);
  }

  @override
  Widget build(BuildContext context) {
    // Çerçeve (albüm, ebeveyn alanı, kutlama) ve türün düğmeleri onaylı
    // koyu tasarımda; resim kartları kendi yumuşak renklerini korur.
    return StudioChrome(child: KidFrame(play: play, hooks: hooks, child: widget.rules.kind.build(play)));
  }
}

EgiticiRules egiticiRules(String gameId, EgiticiKind kind) => EgiticiRules(gameId: gameId, kind: kind);

// ---------------------------------------------------------------- ortak yardımcılar

int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

String pickL(List<String> l, String lang) => Strings.pick(l, lang);

/// Sakin, yumuşak çocuk paleti.
class KColors {
  static const paper = Color(0xFFFBF7EF);
  static const ink = Color(0xFF2E3A4B);
  static const soft = Color(0xFFEDE6D8);
  static const line = Color(0xFFCBBFA8);
  static const good = Color(0xFF5BAA6E);
  static const bad = Color(0xFFE07A5F);
  static const sky = Color(0xFF8EC5E8);
  static const sun = Color(0xFFF6C85F);
  static const accent = Color(0xFF4F86C6);
  static const List<Color> tiles = [
    Color(0xFFFFE3B3),
    Color(0xFFD7EEDC),
    Color(0xFFD6E6F7),
    Color(0xFFF7D9E3),
    Color(0xFFE8DEF5),
    Color(0xFFFFF1C1),
  ];
}

/// Saat ve iptal edilebilen gecikmeler.
mixin Clock<T extends StatefulWidget> on State<T> {
  int seconds = 0;
  bool ended = false;
  Timer? _t;
  final List<Timer> _later = [];

  void startClock() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ended && mounted) seconds++;
    });
  }

  void later(int ms, VoidCallback f) {
    _later.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }));
  }

  @override
  void dispose() {
    _t?.cancel();
    for (final t in _later) {
      t.cancel();
    }
    super.dispose();
  }
}

/// Mantıksal birimlerle çizilen, dokunuşları aynı birimlere çeviren tuval.
class TapCanvas extends StatelessWidget {
  final double w;
  final double h;
  final void Function(Canvas c) paint;
  final void Function(Offset p)? onTap;
  final void Function(Offset p)? onPanStart;
  final void Function(Offset p)? onPanUpdate;
  final VoidCallback? onPanEnd;
  final String? semantics;
  const TapCanvas({
    super.key,
    required this.w,
    required this.h,
    required this.paint,
    this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final mw = box.maxWidth.isFinite ? box.maxWidth : 360.0;
      final mh = box.maxHeight.isFinite ? box.maxHeight : 360.0;
      final k = math.min(mw / w, mh / h);
      final size = Size(w * k, h * k);
      Offset lp(Offset o) => o / k;
      final ps = onPanStart, pu = onPanUpdate, pe = onPanEnd, t = onTap;
      return Center(
        child: Semantics(
          label: semantics,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: t == null ? null : (e) => t(lp(e.localPosition)),
            onPanStart: ps == null ? null : (e) => ps(lp(e.localPosition)),
            onPanUpdate: pu == null ? null : (e) => pu(lp(e.localPosition)),
            onPanEnd: pe == null ? null : (_) => pe(),
            child: CustomPaint(size: size, painter: _FnPainter(paint, k)),
          ),
        ),
      );
    });
  }
}

class _FnPainter extends CustomPainter {
  final void Function(Canvas c) fn;
  final double k;
  _FnPainter(this.fn, this.k);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    fn(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FnPainter old) => true;
}

Paint fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Ortalanmış kısa yazı (mantıksal birimlerle).
void drawLabel(Canvas c, String s, Offset center, double size, Color color, {FontWeight weight = FontWeight.w700}) {
  if (s.isEmpty) return;
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.0)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Düz sayı listesinden çokgen yolu.
Path polyPath(List<int> xy, {double sx = 1, double sy = 1, double dx = 0, double dy = 0}) {
  final p = Path();
  for (var i = 0; i + 1 < xy.length; i += 2) {
    final x = xy[i] * sx + dx, y = xy[i + 1] * sy + dy;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  p.close();
  return p;
}

bool polyContains(List<int> xy, double x, double y) {
  var inside = false;
  final n = xy.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = xy[2 * i].toDouble(), yi = xy[2 * i + 1].toDouble();
    final xj = xy[2 * j].toDouble(), yj = xy[2 * j + 1].toDouble();
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

/// Yerel rakamlar (Arapça, Farsça, Urduca, Hintçe, Bengalce).
String localNum(int n, String lang, Map<String, String> digits) {
  final s = n.toString();
  final d = digits[lang];
  if (d == null) return s;
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final v = int.tryParse(ch);
    b.write(v == null ? ch : d[v]);
  }
  return b.toString();
}

/// Büyük, yuvarlak, kolay dokunulan düğme (onaylı tasarımın degrade
/// yuvarlağı; renk verilmezse paletin kart rengi). Simge rengi zemine göre
/// seçilir, böylece açık renkli düğmelerde de okunur.
class BigButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final String? tooltip;
  const BigButton({super.key, required this.child, this.onTap, this.color, this.size = 64, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final base = color ?? Color.lerp(look.card, look.accent, 0.12)!;
    final fg = base.computeLuminance() > 0.35 ? KColors.ink : Colors.white;
    final b = Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: look.accent.withValues(alpha: 0.65), width: 2)),
        elevation: 0,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(base, Colors.white, 0.14)!, Color.lerp(base, Colors.black, 0.22)!],
            ),
            boxShadow: [BoxShadow(color: look.accent.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: Center(child: child)),
              ),
            ),
          ),
        ),
      ),
    );
    final t = tooltip;
    return t == null ? b : Tooltip(message: t, child: b);
  }
}

/// Bölüm ilerleme noktaları.
class StepDots extends StatelessWidget {
  final int done;
  final int total;
  const StepDots({super.key, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: [
      for (var i = 0; i < total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: i < done ? 16 : 12,
          height: i < done ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < done ? StudioLook.good : Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: i < done ? Colors.white70 : Colors.white38),
          ),
        ),
    ]);
  }
}
