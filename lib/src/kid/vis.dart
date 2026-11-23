import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core.dart';
import '../data/alpha.dart';
import '../data/flags.dart';
import '../data/names.dart';
import '../data/words.dart';
import '../data/world.dart';

/// Görsel türleri. Bölüm verisi yalnızca sayı ve kısa dizgi taşır; ad ve
/// harfler oyun anında oyuncunun diline göre çözülür.
enum VT {
  emoji, // s = emoji, c = dönüşüm bitleri (1 ayna, 2 ters, 4 yarı saydam)
  text, // s = metin
  letter, // a = sıra, b = kaydırma, c = 1 küçük harf
  letters, // harf dizisi: a = ilk sıra, b = kaydırma, c = adet (son yerine ?)
  number, // a = sayı
  numSeq, // a = ilk, b = adım, c = boşluk sırası (s = '4' adet)
  count, // s = emoji, a = adet
  clock, // a = saat, b = dakika
  digital, // a = saat, b = dakika
  color, // a = renk, c = 1 ad
  colorName, // a = renk
  shape, // a = 2B şekil, b = renk, c = 1 ad
  shape3, // a = 3B cisim
  shapeName, // a = şekil (0..9 2B, 10.. 3B)
  frac, // a / b, c = 0 pasta 1 çubuk
  fracText, // a / b
  flag, // s = ülke kodu
  country, // s = ülke kodu (ad)
  capital, // s = ülke kodu (başkent)
  mapc, // s = ülke kodu (harita)
  coins, // s = '1,5,10'
  money, // a = tutar
  staff, // a = nota (0 = do4 … 14 = do6)
  note, // a = nota adı
  planet, // a = gezegen, c = 1 ad
  planetName, // a = gezegen
  orbit, // a = Güneş'ten sıra (1..8)
  season, // a = mevsim, c = 1 ad
  seasonName, // a = mevsim
  sign, // a = trafik işareti
  signName, // a = işaret
  light, // a = 0 kırmızı 1 sarı 2 yeşil
  eq, // a op b = ? (c: 0 + 1 − 2 × 3 ÷)
  dots, // a × b nokta dizisi
  animal, // a = hayvan, c = 1 ad
  animalName, // a = hayvan
  sound, // a = hayvan sesi
  home, // a = yaşam alanı
  word, // a = kelime (ad)
}

class Vis {
  final VT t;
  final int a;
  final int b;
  final int c;
  final String s;
  const Vis(this.t, {this.a = 0, this.b = 0, this.c = 0, this.s = ''});

  String get key => '${t.index}:$a:$b:$c:$s';
}

/// Harf sırası: kaydırma, alfabenin sonunu aşmayacak biçimde uygulanır.
String letterAt(String lang, int i, int off, {bool lower = false}) {
  final up = kAlphaUpper[lang] ?? kAlphaUpper['en']!;
  final lo = kAlphaLower[lang] ?? kAlphaLower['en']!;
  final span = up.length - 19;
  final k = clampI(i + (span > 0 ? off % span : 0), 0, up.length - 1);
  return lower ? lo[k] : up[k];
}

bool bicameral(String lang) {
  final up = kAlphaUpper[lang] ?? const [];
  final lo = kAlphaLower[lang] ?? const [];
  for (var i = 0; i < up.length && i < lo.length; i++) {
    if (up[i] != lo[i]) return true;
  }
  return false;
}

String nm(String key, String lang) => pickL(kNames[key] ?? const [''], lang);

String numL(int n, String lang) => localNum(n, lang, kDigits);

String currency(String lang) {
  switch (lang) {
    case 'tr': {
      return '₺';
    }
    case 'de':
    case 'es':
    case 'fr':
    case 'it':
    case 'pt':
    case 'nl':
    case 'fi':
    case 'el': {
      return '€';
    }
    case 'ja':
    case 'zh': {
      return '¥';
    }
    case 'ko': {
      return '₩';
    }
    case 'hi':
    case 'ur': {
      return '₹';
    }
    case 'ru': {
      return '₽';
    }
    case 'uk': {
      return '₴';
    }
    case 'pl': {
      return 'zł';
    }
    case 'bn': {
      return '৳';
    }
    case 'th': {
      return '฿';
    }
    case 'vi': {
      return '₫';
    }
    case 'fil': {
      return '₱';
    }
    default: {
      return '\$';
    }
  }
}

String moneyText(int v, String lang) => '${numL(v, lang)} ${currency(lang)}';

String countryName(String code, String lang) => pickL(kCountryNames[code] ?? [code], lang);

String capitalOf(String code, String lang) {
  for (final f in kFlags) {
    if (f[0] == code) return lang == 'tr' ? f[2] : f[1];
  }
  return code;
}

String clockText(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';

/// Görseli verilen kare alanda çizer.
class VisView extends StatelessWidget {
  final Vis v;
  final String lang;
  final double size;
  const VisView({super.key, required this.v, required this.lang, this.size = 120});

  Widget _txt(String s, {double k = 0.34, Color color = KColors.ink}) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(s, textAlign: TextAlign.center, style: TextStyle(fontSize: size * k, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
        ),
      );

  Widget _emoji(String e, {int flags = 0}) {
    Widget w = Text(e, style: TextStyle(fontSize: size * 0.56));
    if (flags & 1 != 0) w = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: w);
    if (flags & 2 != 0) w = Transform.rotate(angle: math.pi, child: w);
    if (flags & 4 != 0) w = Opacity(opacity: 0.55, child: w);
    return SizedBox(width: size, height: size, child: Center(child: FittedBox(child: w)));
  }

  Widget _paint(void Function(Canvas c, double s) f, {String label = ''}) {
    final pic = SizedBox(width: size, height: size, child: CustomPaint(painter: _VisPainter(f)));
    if (label.isEmpty) return pic;
    return SizedBox(
      width: size,
      height: size,
      child: Column(children: [
        Expanded(child: CustomPaint(size: Size(size, size * 0.78), painter: _VisPainter(f))),
        SizedBox(
          height: size * 0.22,
          child: FittedBox(child: Text(label, style: TextStyle(fontSize: size * 0.16, fontWeight: FontWeight.w700, color: KColors.ink))),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (v.t) {
      case VT.emoji: {
        return _emoji(v.s, flags: v.c);
      }
      case VT.text: {
        return _txt(v.s, k: 0.24);
      }
      case VT.letter: {
        return _txt(letterAt(lang, v.a, v.b, lower: v.c == 1), k: 0.56);
      }
      case VT.letters: {
        return _txt([for (var i = 0; i < v.c; i++) letterAt(lang, v.a + i, v.b)].join(' ') + ' ?', k: 0.3);
      }
      case VT.number: {
        return _txt(numL(v.a, lang), k: 0.5);
      }
      case VT.numSeq: {
        final n = int.tryParse(v.s) ?? 4;
        return _txt([for (var i = 0; i < n; i++) i == v.c ? '?' : numL(v.a + i * v.b, lang)].join('  '), k: 0.26);
      }
      case VT.count: {
        return _paint((c, s) => paintCount(c, s, v.s, v.a));
      }
      case VT.clock: {
        return _paint((c, s) => paintClock(c, s, v.a, v.b, lang));
      }
      case VT.digital: {
        return _txt(clockText(v.a, v.b), k: 0.36);
      }
      case VT.color: {
        return _paint((c, s) => paintBlob(c, s, Color(kColorValues[v.a % kColorValues.length])),
            label: v.c == 1 ? nm(kColorKeys[v.a % kColorKeys.length], lang) : '');
      }
      case VT.colorName: {
        return _txt(nm(kColorKeys[v.a % kColorKeys.length], lang), k: 0.22);
      }
      case VT.shape: {
        return _paint((c, s) => paintShape(c, s, v.a, Color(kColorValues[v.b % kColorValues.length])),
            label: v.c == 1 ? nm(kShape2D[v.a % kShape2D.length], lang) : '');
      }
      case VT.shape3: {
        return _paint((c, s) => paintSolid(c, s, v.a), label: v.c == 1 ? nm(kShape3D[v.a % kShape3D.length], lang) : '');
      }
      case VT.shapeName: {
        return _txt(v.a < 10 ? nm(kShape2D[v.a], lang) : nm(kShape3D[(v.a - 10) % kShape3D.length], lang), k: 0.2);
      }
      case VT.frac: {
        return _paint((c, s) => paintFrac(c, s, v.a, v.b, v.c == 1));
      }
      case VT.fracText: {
        return _paint((c, s) => paintFracText(c, s, numL(v.a, lang), numL(v.b, lang)));
      }
      case VT.flag: {
        return _paint((c, s) => paintFlag(c, s, v.s));
      }
      case VT.country: {
        return _txt(countryName(v.s, lang), k: 0.18);
      }
      case VT.capital: {
        return _txt(capitalOf(v.s, lang), k: 0.2);
      }
      case VT.mapc: {
        return _paint((c, s) => paintMap(c, s, v.s));
      }
      case VT.coins: {
        return _paint((c, s) => paintCoins(c, s, [for (final x in v.s.split(',')) int.tryParse(x) ?? 1], lang));
      }
      case VT.money: {
        return _txt(moneyText(v.a, lang), k: 0.3);
      }
      case VT.staff: {
        return _paint((c, s) => paintStaff(c, s, v.a));
      }
      case VT.note: {
        return _txt((kNoteNames[lang] ?? kNoteNames['en']!)[v.a % 7], k: 0.32);
      }
      case VT.planet: {
        return _paint((c, s) => paintPlanet(c, s, v.a), label: v.c == 1 ? nm(kPlanetKeys[v.a % kPlanetKeys.length], lang) : '');
      }
      case VT.planetName: {
        return _txt(nm(kPlanetKeys[v.a % kPlanetKeys.length], lang), k: 0.2);
      }
      case VT.orbit: {
        return _paint((c, s) => paintOrbit(c, s, v.a));
      }
      case VT.season: {
        return _paint((c, s) => paintSeason(c, s, v.a), label: v.c == 1 ? nm(kSeasonKeys[v.a % 4], lang) : '');
      }
      case VT.seasonName: {
        return _txt(nm(kSeasonKeys[v.a % 4], lang), k: 0.22);
      }
      case VT.sign: {
        return _paint((c, s) => paintSign(c, s, v.a));
      }
      case VT.signName: {
        return _txt(nm(kTrafficKeys[v.a % kTrafficKeys.length], lang), k: 0.17);
      }
      case VT.light: {
        return _paint((c, s) => paintLight(c, s, v.a));
      }
      case VT.eq: {
        final op = const ['+', '−', '×', '÷'][v.c % 4];
        if (v.s.isNotEmpty) return _txt('${v.s * v.a} $op ${v.s * v.b}', k: 0.16);
        return _txt('${numL(v.a, lang)} $op ${numL(v.b, lang)} = ?', k: 0.24);
      }
      case VT.dots: {
        return _paint((c, s) => paintDots(c, s, v.a, v.b));
      }
      case VT.animal: {
        final i = v.a % kAnimalEmoji.length;
        if (v.c != 1) return _emoji(kAnimalEmoji[i]);
        return SizedBox(
          width: size,
          height: size,
          child: Column(children: [
            Expanded(child: FittedBox(child: Text(kAnimalEmoji[i], style: TextStyle(fontSize: size * 0.5)))),
            SizedBox(height: size * 0.22, child: FittedBox(child: Text(nm(kAnimalKeys[i], lang), style: const TextStyle(fontWeight: FontWeight.w700)))),
          ]),
        );
      }
      case VT.animalName: {
        return _txt(nm(kAnimalKeys[v.a % kAnimalKeys.length], lang), k: 0.2);
      }
      case VT.sound: {
        return SizedBox(width: size, height: size, child: Icon(Icons.volume_up_rounded, size: size * 0.6, color: KColors.accent));
      }
      case VT.home: {
        return _emoji(kHomeEmoji[v.a % kHomeEmoji.length]);
      }
      case VT.word: {
        return _txt(nm(kWordKeys[v.a % kWordKeys.length], lang), k: 0.2);
      }
    }
  }
}

class _VisPainter extends CustomPainter {
  final void Function(Canvas c, double s) f;
  _VisPainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    f(canvas, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VisPainter old) => true;
}

// ---------------------------------------------------------------- çizimler

void paintCount(Canvas c, double s, String emoji, int n) {
  final cols = n <= 4 ? 2 : (n <= 9 ? 3 : (n <= 16 ? 4 : 5));
  final rows = (n + cols - 1) ~/ cols;
  final cell = s / math.max(cols, rows);
  final ox = (s - cols * cell) / 2, oy = (s - rows * cell) / 2;
  for (var i = 0; i < n; i++) {
    final x = ox + (i % cols + 0.5) * cell, y = oy + (i ~/ cols + 0.5) * cell;
    final tp = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: cell * 0.72)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }
}

void paintClock(Canvas c, double s, int h, int m, String lang) {
  final o = Offset(s / 2, s / 2);
  final r = s * 0.44;
  c.drawCircle(o, r, fill(Colors.white));
  c.drawCircle(o, r, stroke(KColors.ink, s * 0.03));
  for (var i = 1; i <= 12; i++) {
    final a = -math.pi / 2 + i * math.pi / 6;
    drawLabel(c, '$i', o + Offset(math.cos(a), math.sin(a)) * (r * 0.78), s * 0.09, KColors.ink);
  }
  for (var i = 0; i < 60; i++) {
    final a = -math.pi / 2 + i * math.pi / 30;
    final r0 = i % 5 == 0 ? r * 0.9 : r * 0.95;
    c.drawLine(o + Offset(math.cos(a), math.sin(a)) * r0, o + Offset(math.cos(a), math.sin(a)) * r, stroke(KColors.line, s * 0.008));
  }
  final ha = -math.pi / 2 + ((h % 12) + m / 60) * math.pi / 6;
  final ma = -math.pi / 2 + m * math.pi / 30;
  c.drawLine(o, o + Offset(math.cos(ha), math.sin(ha)) * (r * 0.5), stroke(const Color(0xFFC8553D), s * 0.045));
  c.drawLine(o, o + Offset(math.cos(ma), math.sin(ma)) * (r * 0.78), stroke(KColors.accent, s * 0.03));
  c.drawCircle(o, s * 0.03, fill(KColors.ink));
}

void paintBlob(Canvas c, double s, Color col) {
  final p = Path();
  const n = 12;
  for (var i = 0; i <= n; i++) {
    final a = i * 2 * math.pi / n;
    final r = s * (0.36 + 0.05 * math.sin(i * 2.3));
    final pt = Offset(s / 2 + r * math.cos(a), s / 2 + r * math.sin(a));
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  c.drawPath(p, fill(col));
  c.drawPath(p, stroke(Colors.black26, s * 0.015));
}

Path shapePath(int i, double s) {
  final cx = s / 2, cy = s / 2, r = s * 0.38;
  Path reg(int k, double rot) {
    final p = Path();
    for (var j = 0; j < k; j++) {
      final a = rot + j * 2 * math.pi / k;
      final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      if (j == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  switch (i % 10) {
    case 0: {
      return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
    case 1: {
      return Path()..addRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.55, height: r * 1.55));
    }
    case 2: {
      return reg(3, -math.pi / 2);
    }
    case 3: {
      return Path()..addRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.15));
    }
    case 4: {
      return Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.3));
    }
    case 5: {
      final p = Path();
      for (var j = 0; j < 10; j++) {
        final rr = j.isEven ? r : r * 0.45;
        final a = -math.pi / 2 + j * math.pi / 5;
        final pt = Offset(cx + rr * math.cos(a), cy + rr * math.sin(a));
        if (j == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      return p..close();
    }
    case 6: {
      final p = Path()..moveTo(cx, cy + r * 0.95);
      p.cubicTo(cx - r * 1.5, cy - r * 0.1, cx - r * 0.5, cy - r * 1.1, cx, cy - r * 0.35);
      p.cubicTo(cx + r * 0.5, cy - r * 1.1, cx + r * 1.5, cy - r * 0.1, cx, cy + r * 0.95);
      return p..close();
    }
    case 7: {
      return Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r * 0.7, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r * 0.7, cy)
        ..close();
    }
    case 8: {
      return reg(5, -math.pi / 2);
    }
    default: {
      return reg(6, 0);
    }
  }
}

/// Kenar sayısı (daire, oval, kalp için 0).
int shapeSides(int i) => const [0, 4, 3, 4, 0, 10, 0, 4, 5, 6][i % 10];

void paintShape(Canvas c, double s, int i, Color col) {
  final p = shapePath(i, s);
  c.drawPath(p, fill(col));
  c.drawPath(p, stroke(Colors.black38, s * 0.02));
}

void paintSolid(Canvas c, double s, int i) {
  final ink = stroke(KColors.ink, s * 0.02);
  final cx = s / 2;
  switch (i % 4) {
    case 0: {
      final a = s * 0.3, d = s * 0.14;
      final front = Rect.fromLTWH(cx - a / 2 - d / 2, s * 0.32, a, a);
      final top = Path()
        ..moveTo(front.left, front.top)
        ..lineTo(front.left + d, front.top - d)
        ..lineTo(front.right + d, front.top - d)
        ..lineTo(front.right, front.top)
        ..close();
      final side = Path()
        ..moveTo(front.right, front.top)
        ..lineTo(front.right + d, front.top - d)
        ..lineTo(front.right + d, front.bottom - d)
        ..lineTo(front.right, front.bottom)
        ..close();
      c.drawRect(front, fill(const Color(0xFFF6C85F)));
      c.drawPath(top, fill(const Color(0xFFFFE29A)));
      c.drawPath(side, fill(const Color(0xFFD9A441)));
      c.drawRect(front, ink);
      c.drawPath(top, ink);
      c.drawPath(side, ink);
    }
    case 1: {
      final o = Offset(cx, s / 2);
      final r = s * 0.3;
      c.drawCircle(o, r, Paint()..shader = RadialGradient(colors: const [Color(0xFFBFE3FF), Color(0xFF3A86C8)], center: const Alignment(-0.4, -0.4)).createShader(Rect.fromCircle(center: o, radius: r)));
      c.drawCircle(o, r, ink);
    }
    case 2: {
      final w = s * 0.4, top = s * 0.25, bot = s * 0.72, eh = s * 0.12;
      final body = Rect.fromLTRB(cx - w / 2, top, cx + w / 2, bot);
      c.drawRect(body, fill(const Color(0xFF7BC67E)));
      c.drawOval(Rect.fromCenter(center: Offset(cx, bot), width: w, height: eh), fill(const Color(0xFF7BC67E)));
      c.drawOval(Rect.fromCenter(center: Offset(cx, top), width: w, height: eh), fill(const Color(0xFFB8E0B9)));
      c.drawLine(body.topLeft, body.bottomLeft, ink);
      c.drawLine(body.topRight, body.bottomRight, ink);
      c.drawOval(Rect.fromCenter(center: Offset(cx, top), width: w, height: eh), ink);
      c.drawArc(Rect.fromCenter(center: Offset(cx, bot), width: w, height: eh), 0, math.pi, false, ink);
    }
    default: {
      final w = s * 0.44, top = s * 0.2, bot = s * 0.74, eh = s * 0.12;
      final p = Path()
        ..moveTo(cx, top)
        ..lineTo(cx + w / 2, bot)
        ..arcTo(Rect.fromCenter(center: Offset(cx, bot), width: w, height: eh), 0, math.pi, false)
        ..close();
      c.drawPath(p, fill(const Color(0xFFE07A5F)));
      c.drawPath(p, ink);
    }
  }
}

void paintFrac(Canvas c, double s, int num, int den, bool bar) {
  final on = fill(const Color(0xFFF4A261)), off = fill(const Color(0xFFF3EDE2));
  final ink = stroke(KColors.ink, s * 0.018);
  if (bar) {
    final w = s * 0.84, h = s * 0.34, x0 = s * 0.08, y0 = s * 0.33;
    for (var i = 0; i < den; i++) {
      final r = Rect.fromLTWH(x0 + i * w / den, y0, w / den, h);
      c.drawRect(r, i < num ? on : off);
      c.drawRect(r, ink);
    }
    return;
  }
  final o = Offset(s / 2, s / 2);
  final r = s * 0.4;
  final box = Rect.fromCircle(center: o, radius: r);
  for (var i = 0; i < den; i++) {
    final a0 = -math.pi / 2 + i * 2 * math.pi / den;
    c.drawArc(box, a0, 2 * math.pi / den, true, i < num ? on : off);
    c.drawArc(box, a0, 2 * math.pi / den, true, ink);
  }
}

void paintFracText(Canvas c, double s, String a, String b) {
  drawLabel(c, a, Offset(s / 2, s * 0.3), s * 0.28, KColors.ink);
  c.drawLine(Offset(s * 0.3, s / 2), Offset(s * 0.7, s / 2), stroke(KColors.ink, s * 0.03));
  drawLabel(c, b, Offset(s / 2, s * 0.72), s * 0.28, KColors.ink);
}

Color hexC(String h) => Color(int.parse('FF$h', radix: 16));

/// Bayrak komutlarını (300×200) verilen genişliğe çizer.
void drawFlag(Canvas c, String code, Rect box) {
  String? spec;
  for (final f in kFlags) {
    if (f[0] == code) spec = f[3];
  }
  if (spec == null) return;
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.03)));
  c.translate(box.left, box.top);
  c.scale(box.width / 300, box.height / 200);
  for (final part in spec.split(';')) {
    final t = part.trim().split(RegExp(r'\s+'));
    if (t.isEmpty) continue;
    double n(int i) => double.parse(t[i]);
    switch (t[0]) {
      case 'H': {
        final k = t.length - 1;
        for (var i = 0; i < k; i++) {
          c.drawRect(Rect.fromLTWH(0, 200 * i / k, 300, 200 / k + 0.6), fill(hexC(t[i + 1])));
        }
      }
      case 'V': {
        final k = t.length - 1;
        for (var i = 0; i < k; i++) {
          c.drawRect(Rect.fromLTWH(300 * i / k, 0, 300 / k + 0.6, 200), fill(hexC(t[i + 1])));
        }
      }
      case 'R': {
        c.drawRect(Rect.fromLTWH(n(1), n(2), n(3), n(4)), fill(hexC(t[5])));
      }
      case 'C': {
        c.drawCircle(Offset(n(1), n(2)), n(3), fill(hexC(t[4])));
      }
      case 'S': {
        final p = Path();
        for (var j = 0; j < 10; j++) {
          final rr = j.isEven ? n(3) : n(3) * 0.4;
          final a = -math.pi / 2 + j * math.pi / 5;
          final pt = Offset(n(1) + rr * math.cos(a), n(2) + rr * math.sin(a));
          if (j == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        c.drawPath(p..close(), fill(hexC(t[4])));
      }
      case 'P': {
        final p = Path()..moveTo(n(2), n(3));
        for (var j = 4; j + 1 < t.length; j += 2) {
          p.lineTo(n(j), n(j + 1));
        }
        c.drawPath(p..close(), fill(hexC(t[1])));
      }
    }
  }
  c.restore();
  c.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.03)), stroke(Colors.black26, 1));
}

void paintFlag(Canvas c, double s, String code) {
  final w = s * 0.9, h = w * 2 / 3;
  drawFlag(c, code, Rect.fromLTWH((s - w) / 2, (s - h) / 2, w, h));
}

/// Ülkeyi kendi çevresinin haritasında vurgular (eşdikdörtgen izdüşüm).
void paintMap(Canvas c, double s, String code) {
  List<Object>? target;
  for (final e in kWorld) {
    if (e[0] == code) target = e;
  }
  if (target == null) return;
  var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
  for (final r in target.skip(1)) {
    final xy = r as List<int>;
    for (var i = 0; i + 1 < xy.length; i += 2) {
      minX = math.min(minX, xy[i] / 10);
      maxX = math.max(maxX, xy[i] / 10);
      minY = math.min(minY, xy[i + 1] / 10);
      maxY = math.max(maxY, xy[i + 1] / 10);
    }
  }
  if (maxX - minX > 180) {
    minX = -180;
    maxX = 180;
  }
  final cxg = (minX + maxX) / 2, cyg = (minY + maxY) / 2;
  final cosL = clampD(math.cos(cyg * math.pi / 180).abs(), 0.35, 1.0);
  final span = math.max(30.0, math.max((maxX - minX) * cosL, maxY - minY) * 2.6);
  final k = s / span;
  final left = cxg * cosL - span / 2, top = cyg + span / 2;
  Offset pr(int lon10, int lat10) => Offset((lon10 / 10 * cosL - left) * k, (top - lat10 / 10) * k);
  final lonMin = cxg - span / cosL, lonMax = cxg + span / cosL;
  c.save();
  final box = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.06));
  c.clipRRect(box);
  c.drawRect(Rect.fromLTWH(0, 0, s, s), fill(const Color(0xFFCFE6F5)));
  for (final e in kWorld) {
    final me = e[0] == code;
    for (final r in e.skip(1)) {
      final xy = r as List<int>;
      var near = false;
      for (var i = 0; i + 1 < xy.length; i += 2) {
        final lon = xy[i] / 10, lat = xy[i + 1] / 10;
        if (lon > lonMin && lon < lonMax && lat > cyg - span && lat < cyg + span) {
          near = true;
          break;
        }
      }
      if (!near) continue;
      final p = Path();
      for (var i = 0; i + 1 < xy.length; i += 2) {
        final o = pr(xy[i], xy[i + 1]);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      p.close();
      c.drawPath(p, fill(me ? const Color(0xFFE07A5F) : const Color(0xFFF1EBDD)));
      c.drawPath(p, stroke(me ? const Color(0xFF8C3B2A) : const Color(0xFFB9AE9B), me ? 1.6 : 0.8));
    }
  }
  c.restore();
  c.drawRRect(box, stroke(Colors.black12, 1.5));
}

void paintCoins(Canvas c, double s, List<int> vals, String lang) {
  final n = vals.length;
  final cols = n <= 2 ? n : (n <= 4 ? 2 : 3);
  final rows = (n + cols - 1) ~/ cols;
  final cw = s / cols, ch = s / math.max(rows, 2);
  for (var i = 0; i < n; i++) {
    final v = vals[i];
    final o = Offset((i % cols + 0.5) * cw, (i ~/ cols + 0.5) * ch + (s - rows * ch) / 2);
    if (v >= 20) {
      final r = Rect.fromCenter(center: o, width: cw * 0.9, height: ch * 0.55);
      final col = v >= 100 ? const Color(0xFF9DD3C8) : (v >= 50 ? const Color(0xFFF6C1A8) : const Color(0xFFC9D8F2));
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), fill(col));
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), stroke(Colors.black38, 1.5));
      c.drawCircle(r.centerLeft + Offset(r.width * 0.2, 0), r.height * 0.28, stroke(Colors.black26, 1.5));
      drawLabel(c, numL(v, lang), r.center + Offset(r.width * 0.12, 0), ch * 0.24, KColors.ink);
    } else {
      final rad = math.min(cw, ch) * (0.3 + 0.03 * math.min(v, 10) / 2);
      c.drawCircle(o, rad, fill(v >= 5 ? const Color(0xFFF2C14E) : const Color(0xFFD9C7A3)));
      c.drawCircle(o, rad, stroke(const Color(0xFF8A6D1F), 2));
      c.drawCircle(o, rad * 0.8, stroke(const Color(0x668A6D1F), 1));
      drawLabel(c, numL(v, lang), o, rad * 0.9, KColors.ink);
    }
  }
}

/// Porte: alt çizgi mi4 (2). Nota 0 = do4.
void paintStaff(Canvas c, double s, int note) {
  final gap = s * 0.08;
  final bottom = s * 0.66;
  final x0 = s * 0.08, x1 = s * 0.92;
  for (var i = 0; i < 5; i++) {
    c.drawLine(Offset(x0, bottom - i * gap), Offset(x1, bottom - i * gap), stroke(KColors.ink, s * 0.012));
  }
  final y = bottom - (note - 2) * gap / 2;
  final x = s * 0.55;
  if (note <= 0) c.drawLine(Offset(x - gap * 1.2, bottom + gap), Offset(x + gap * 1.2, bottom + gap), stroke(KColors.ink, s * 0.012));
  if (note >= 12) c.drawLine(Offset(x - gap * 1.2, bottom - 5 * gap), Offset(x + gap * 1.2, bottom - 5 * gap), stroke(KColors.ink, s * 0.012));
  if (note >= 14) c.drawLine(Offset(x - gap * 1.2, bottom - 6 * gap), Offset(x + gap * 1.2, bottom - 6 * gap), stroke(KColors.ink, s * 0.012));
  c.save();
  c.translate(x, y);
  c.rotate(-0.35);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: gap * 1.4, height: gap * 0.95), fill(KColors.ink));
  c.restore();
  final up = note < 6;
  c.drawLine(Offset(x + (up ? gap * 0.66 : -gap * 0.66), y), Offset(x + (up ? gap * 0.66 : -gap * 0.66), y + (up ? -3.2 * gap : 3.2 * gap)), stroke(KColors.ink, s * 0.014));
  // basit sol anahtarı simgesi
  final k = Path()
    ..moveTo(s * 0.17, bottom + gap * 0.8)
    ..cubicTo(s * 0.1, bottom - gap, s * 0.26, bottom - gap * 1.5, s * 0.22, bottom - gap * 2.6)
    ..cubicTo(s * 0.18, bottom - gap * 3.6, s * 0.15, bottom - gap * 4.4, s * 0.19, bottom - gap * 4.9)
    ..cubicTo(s * 0.24, bottom - gap * 4.2, s * 0.16, bottom - gap * 2.6, s * 0.14, bottom - gap * 1.6)
    ..cubicTo(s * 0.12, bottom - gap * 0.4, s * 0.26, bottom - gap * 0.3, s * 0.24, bottom - gap * 1.4)
    ..cubicTo(s * 0.22, bottom - gap * 2.2, s * 0.15, bottom - gap * 1.6, s * 0.17, bottom - gap * 1.1);
  c.drawPath(k, stroke(KColors.ink, s * 0.016));
}

const List<int> _planetCol = [0xFFF6C85F, 0xFFA8A29E, 0xFFE9C98B, 0xFF3A86C8, 0xFFC8553D, 0xFFD9A066, 0xFFE6CF8F, 0xFF8FD3E0, 0xFF4062BB, 0xFFCFCFCF];

void paintPlanet(Canvas c, double s, int i) {
  final o = Offset(s / 2, s / 2);
  final idx = i % 10;
  final r = s * (idx == 0 ? 0.3 : (idx == 5 ? 0.3 : (idx == 6 ? 0.22 : 0.26)));
  final col = Color(_planetCol[idx]);
  if (idx == 0) {
    for (var j = 0; j < 12; j++) {
      final a = j * math.pi / 6;
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * (r * 1.15), o + Offset(math.cos(a), math.sin(a)) * (r * 1.45), stroke(const Color(0xFFF4A261), s * 0.03));
    }
  }
  if (idx == 6) {
    c.drawOval(Rect.fromCenter(center: o, width: r * 3.4, height: r * 1.1), stroke(const Color(0xFFBFA36A), s * 0.04));
  }
  c.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [Color.lerp(col, Colors.white, 0.45)!, col], center: const Alignment(-0.35, -0.35)).createShader(Rect.fromCircle(center: o, radius: r)));
  if (idx == 3) {
    c.drawOval(Rect.fromCenter(center: o + Offset(-r * 0.25, -r * 0.2), width: r * 0.8, height: r * 0.55), fill(const Color(0xFF5BAA6E)));
    c.drawOval(Rect.fromCenter(center: o + Offset(r * 0.35, r * 0.35), width: r * 0.6, height: r * 0.4), fill(const Color(0xFF5BAA6E)));
  }
  if (idx == 5) {
    for (var j = -2; j <= 2; j++) {
      c.drawLine(o + Offset(-r * 0.92, j * r * 0.32), o + Offset(r * 0.92, j * r * 0.32), stroke(const Color(0x66A0522D), s * 0.025));
    }
    c.drawOval(Rect.fromCenter(center: o + Offset(r * 0.35, r * 0.3), width: r * 0.35, height: r * 0.2), fill(const Color(0xFFC8553D)));
  }
  if (idx == 9 || idx == 1) {
    c.drawCircle(o + Offset(-r * 0.3, -r * 0.2), r * 0.15, fill(const Color(0x33000000)));
    c.drawCircle(o + Offset(r * 0.35, r * 0.25), r * 0.12, fill(const Color(0x33000000)));
  }
  if (idx == 6) {
    c.drawArc(Rect.fromCenter(center: o, width: r * 3.4, height: r * 1.1), 0.15, math.pi - 0.3, false, stroke(const Color(0xFFBFA36A), s * 0.04));
  }
  c.drawCircle(o, r, stroke(Colors.black26, s * 0.012));
}

/// Güneş ve sıradaki yörünge: [k]. gezegen soru işareti.
void paintOrbit(Canvas c, double s, int k) {
  final y = s / 2;
  c.drawCircle(Offset(-s * 0.05, y), s * 0.2, fill(const Color(0xFFF6C85F)));
  for (var i = 1; i <= 8; i++) {
    final x = s * 0.18 + i * s * 0.095;
    if (i == k) {
      c.drawCircle(Offset(x, y), s * 0.05, fill(KColors.accent));
      drawLabel(c, '?', Offset(x, y - s * 0.12), s * 0.14, KColors.ink);
    } else {
      c.drawCircle(Offset(x, y), s * 0.025, fill(Colors.black26));
    }
  }
}

void paintSeason(Canvas c, double s, int i) {
  final sky = [const Color(0xFFDFF2E1), const Color(0xFFCFE8FA), const Color(0xFFF8E3C8), const Color(0xFFE4ECF4)][i % 4];
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92), Radius.circular(s * 0.1)), fill(sky));
  final trunk = Rect.fromLTWH(s * 0.46, s * 0.5, s * 0.08, s * 0.36);
  c.drawRect(trunk, fill(const Color(0xFF8D6748)));
  final o = Offset(s / 2, s * 0.42);
  switch (i % 4) {
    case 0: {
      c.drawCircle(o, s * 0.24, fill(const Color(0xFF9ED39F)));
      for (var j = 0; j < 9; j++) {
        final a = j * 0.7;
        c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * (s * 0.15), s * 0.035, fill(const Color(0xFFF7A8C4)));
      }
    }
    case 1: {
      c.drawCircle(o, s * 0.26, fill(const Color(0xFF4F9A6E)));
      c.drawCircle(Offset(s * 0.8, s * 0.2), s * 0.08, fill(const Color(0xFFF6C85F)));
      for (var j = 0; j < 5; j++) {
        c.drawCircle(o + Offset(math.cos(j * 1.3), math.sin(j * 1.3)) * (s * 0.14), s * 0.03, fill(const Color(0xFFE63946)));
      }
    }
    case 2: {
      c.drawCircle(o, s * 0.22, fill(const Color(0xFFE08A3C)));
      for (var j = 0; j < 6; j++) {
        c.drawOval(Rect.fromCenter(center: Offset(s * (0.2 + j * 0.12), s * (0.78 + (j % 2) * 0.05)), width: s * 0.06, height: s * 0.035), fill(const Color(0xFFC8553D)));
      }
    }
    default: {
      final br = stroke(const Color(0xFF8D6748), s * 0.025);
      c.drawLine(Offset(s / 2, s * 0.55), Offset(s * 0.32, s * 0.3), br);
      c.drawLine(Offset(s / 2, s * 0.5), Offset(s * 0.68, s * 0.28), br);
      c.drawLine(Offset(s / 2, s * 0.5), Offset(s / 2, s * 0.22), br);
      c.drawRect(Rect.fromLTWH(s * 0.04, s * 0.82, s * 0.92, s * 0.14), fill(Colors.white));
      for (var j = 0; j < 10; j++) {
        c.drawCircle(Offset(s * (0.1 + (j * 37 % 80) / 100), s * (0.12 + (j * 53 % 60) / 100)), s * 0.015, fill(Colors.white));
      }
    }
  }
}

void paintLight(Canvas c, double s, int on) {
  final box = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.34, s * 0.06, s * 0.32, s * 0.82), Radius.circular(s * 0.08));
  c.drawRRect(box, fill(const Color(0xFF2E3A4B)));
  const cols = [Color(0xFFE63946), Color(0xFFF6C85F), Color(0xFF4CC46B)];
  for (var i = 0; i < 3; i++) {
    final o = Offset(s / 2, s * (0.2 + i * 0.27));
    c.drawCircle(o, s * 0.1, fill(i == on ? cols[i] : const Color(0xFF55606F)));
  }
}

void paintSign(Canvas c, double s, int i) {
  final o = Offset(s / 2, s / 2);
  final r = s * 0.4;
  void emoji(String e, double k, [Offset? at]) {
    final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: s * k)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, (at ?? o) - Offset(tp.width / 2, tp.height / 2));
  }

  switch (i % 8) {
    case 0: { // dur
      final p = Path();
      for (var j = 0; j < 8; j++) {
        final a = math.pi / 8 + j * math.pi / 4;
        final pt = o + Offset(math.cos(a), math.sin(a)) * r;
        if (j == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      c.drawPath(p..close(), fill(const Color(0xFFD62828)));
      c.drawPath(p, stroke(Colors.white, s * 0.025));
      emoji('✋', 0.34);
    }
    case 1: {
      paintLight(c, s, 2);
    }
    case 2: {
      paintLight(c, s, 1);
    }
    case 3: { // yaya geçidi
      c.drawRect(Rect.fromCenter(center: o, width: r * 1.8, height: r * 1.8), fill(const Color(0xFF2F6DB5)));
      final tri = Path()
        ..moveTo(o.dx, o.dy - r * 0.75)
        ..lineTo(o.dx + r * 0.8, o.dy + r * 0.6)
        ..lineTo(o.dx - r * 0.8, o.dy + r * 0.6)
        ..close();
      c.drawPath(tri, fill(Colors.white));
      for (var j = 0; j < 4; j++) {
        c.drawRect(Rect.fromLTWH(o.dx - r * 0.55 + j * r * 0.3, o.dy + r * 0.32, r * 0.16, r * 0.2), fill(KColors.ink));
      }
      emoji('🚶', 0.2, o + Offset(0, -r * 0.12));
    }
    case 4: { // girilmez
      c.drawCircle(o, r, fill(const Color(0xFFD62828)));
      c.drawRect(Rect.fromCenter(center: o, width: r * 1.4, height: r * 0.34), fill(Colors.white));
    }
    case 5: { // okul
      final tri = Path()
        ..moveTo(o.dx, o.dy - r)
        ..lineTo(o.dx + r, o.dy + r * 0.75)
        ..lineTo(o.dx - r, o.dy + r * 0.75)
        ..close();
      c.drawPath(tri, fill(Colors.white));
      c.drawPath(tri, stroke(const Color(0xFFD62828), s * 0.06));
      emoji('🧒', 0.24, o + Offset(-r * 0.2, r * 0.25));
      emoji('🧒', 0.2, o + Offset(r * 0.25, r * 0.3));
    }
    case 6: { // bisiklet yolu
      c.drawCircle(o, r, fill(const Color(0xFF2F6DB5)));
      emoji('🚲', 0.36);
    }
    default: { // kask
      c.drawCircle(o, r, fill(const Color(0xFFFFF1C1)));
      emoji('🚴', 0.4);
    }
  }
}

void paintDots(Canvas c, double s, int rows, int cols) {
  final cell = s * 0.9 / math.max(math.max(rows, cols), 1);
  final ox = (s - cols * cell) / 2, oy = (s - rows * cell) / 2;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      c.drawCircle(Offset(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell), cell * 0.34, fill(KColors.tiles[y % KColors.tiles.length].withValues(alpha: 1)));
      c.drawCircle(Offset(ox + (x + 0.5) * cell, oy + (y + 0.5) * cell), cell * 0.34, stroke(Colors.black26, 1));
    }
  }
}
