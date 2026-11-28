import 'dart:math' as math;
import 'dart:ui';

/// Harf İzleme için çizgi sırası ve başlangıç noktası verisi.
///
/// Okul el yazısı (düz harf, "top ve çubuk") sırası esas alınır: önce dik
/// çizgiler yukarıdan aşağı, sonra yatay çizgiler soldan sağa; yuvarlak
/// harfler saat yönünün tersine, en üstten ya da sağ üstten başlar.
///
/// Koordinatlar harfin kendi kutusunda 0–10 arasıdır (y aşağı doğru);
/// ekranda çizilen harfin gerçek kutusuna oturtulur, böylece yazı tipinden
/// bağımsız kalır. Komutlar: `M x y` başla, `L x y` çizgi,
/// `C cx cy rx ry a0 a1` elips yayı (derece; 0 sağ, 90 aşağı; a1 < a0 ise
/// saat yönünün tersine). Çizgiler `|` ile ayrılır.
///
/// Verisi olmayan harflerde (aksanlı harfler, Latin dışı yazılar, çift katlı
/// "a" ve "g" gibi yazı tipine göre değişen biçimler) yalnız başlangıç
/// noktası gösterilir.
const Map<String, String> kStrokeSpec = {
  // büyük harfler
  'A': 'M5 0 L0 10|M5 0 L10 10|M2 6.5 L8 6.5',
  'B': 'M0 0 L0 10|M0 0 L5.5 0 C5.5 2.5 4 2.5 -90 90 L0 5|M0 5 L6 5 C6 7.5 4 2.5 -90 90 L0 10',
  'C': 'C5.5 5 4.5 5 -45 -315',
  'D': 'M0 0 L0 10|M0 0 L4 0 C4 5 6 5 -90 90 L0 10',
  'E': 'M0 0 L0 10|M0 0 L10 0|M0 5 L8 5|M0 10 L10 10',
  'F': 'M0 0 L0 10|M0 0 L10 0|M0 5 L8 5',
  'G': 'C5 5 5 5 -40 -360 L6 5',
  'H': 'M0 0 L0 10|M10 0 L10 10|M0 5 L10 5',
  'I': 'M5 0 L5 10',
  'J': 'M10 0 L10 7 C5 7 5 3 0 180',
  'K': 'M0 0 L0 10|M10 0 L0 6|M3 4.5 L10 10',
  'L': 'M0 0 L0 10 L10 10',
  'M': 'M0 0 L0 10|M0 0 L5 7 L10 0 L10 10',
  'N': 'M0 0 L0 10|M0 0 L10 10 L10 0',
  'O': 'C5 5 5 5 -90 -450',
  'P': 'M0 0 L0 10|M0 0 L5 0 C5 2.75 5 2.75 -90 90 L0 5.5',
  'Q': 'C5 5 5 5 -90 -450|M6 7 L10 10',
  'R': 'M0 0 L0 10|M0 0 L5 0 C5 2.75 5 2.75 -90 90 L0 5.5|M4 5.5 L10 10',
  'S': 'C5 2.5 4.8 2.5 -20 -270 C5 7.5 5 2.5 -90 160',
  'T': 'M5 0 L5 10|M0 0 L10 0',
  'U': 'M0 0 L0 6.5 C5 6.5 5 3.5 180 0 L10 0',
  'V': 'M0 0 L5 10 L10 0',
  'W': 'M0 0 L2.5 10 L5 2 L7.5 10 L10 0',
  'X': 'M0 0 L10 10|M10 0 L0 10',
  'Y': 'M0 0 L5 5|M10 0 L5 5 L5 10',
  'Z': 'M0 0 L10 0 L0 10 L10 10',
  // küçük harfler (yazı tipine göre biçimi değişen a ve g yok)
  'b': 'M0 0 L0 10|M0 7 C5 7 5 3 180 540',
  'c': 'C5 5 5 5 -45 -315',
  'd': 'C5 7 5 3 0 -360|M10 0 L10 10',
  'e': 'M0 5 L10 5 C5 5 5 5 0 -315',
  'f': 'C6 2.5 3 2 -45 -180 L3 10|M0 4 L8 4',
  'h': 'M0 0 L0 10|M0 6 C5 6 5 2.5 180 360 L10 10',
  'i': 'M5 3 L5 10|M5 0 L5 0.5',
  'j': 'M8 3 L8 8 C4 8 4 2 0 180|M8 0 L8 0.5',
  'k': 'M0 0 L0 10|M9 3.5 L0 7.5|M3 6 L10 10',
  'l': 'M5 0 L5 10',
  'm': 'M0 0 L0 10|M0 3 C2.5 3 2.5 2.5 180 360 L5 10|M5 3 C7.5 3 2.5 2.5 180 360 L10 10',
  'n': 'M0 0 L0 10|M0 3.5 C5 3.5 5 3.5 180 360 L10 10',
  'o': 'C5 5 5 5 -90 -450',
  'p': 'M0 0 L0 10|M0 3 C5 3 5 3 180 540',
  'q': 'C5 3 5 3 0 -360|M10 0 L10 10',
  'r': 'M0 0 L0 10|M0 4 C6 4 6 3.7 180 300',
  's': 'C5 2.5 4.8 2.5 -20 -270 C5 7.5 5 2.5 -90 160',
  't': 'M3.5 0 L3.5 10|M0 3 L9 3',
  'u': 'M0 0 L0 6 C4.75 6 4.75 4 180 0|M9.5 0 L9.5 10',
  'v': 'M0 0 L5 10 L10 0',
  'w': 'M0 0 L2.5 10 L5 2 L7.5 10 L10 0',
  'x': 'M0 0 L10 10|M10 0 L0 10',
  'y': 'M0 0 L5 6.5|M10 0 L2 10',
  'z': 'M0 0 L10 0 L0 10 L10 10',
  // rakamlar
  '0': 'C5 5 5 5 -90 -450',
  '1': 'M1 2.5 L7 0 L7 10',
  '2': 'C5 3 5 3 200 360 L0 10 L10 10',
  '3': 'C5 2.5 4.5 2.5 200 450 C5 7.5 5 2.5 -90 160',
  '4': 'M7 0 L0 7 L10 7|M7 0 L7 10',
  '5': 'M1 0 L0 4.5 C5 6.8 5 3.2 -150 160|M1 0 L10 0',
  '6': 'C5 5 5 5 -60 -180 L0 6.5 C5 6.5 5 3.5 180 -180',
  '7': 'M0 0 L10 0 L3 10',
  '8': 'C5 2.5 4.5 2.5 -10 -270 C5 7.5 5 2.5 -90 270 L9.4 2',
  '9': 'C5 3.2 5 3.2 0 -360 L9 10',
};

final Map<String, List<List<Offset>>> _cache = {};

/// Harfin çizgileri (0–10 kutusunda), verisi yoksa null.
List<List<Offset>>? strokesFor(String glyph) {
  final spec = kStrokeSpec[glyph];
  if (spec == null) return null;
  return _cache.putIfAbsent(glyph, () => parseStrokes(spec));
}

List<List<Offset>> parseStrokes(String spec) {
  final out = <List<Offset>>[];
  for (final part in spec.split('|')) {
    final t = part.trim().split(RegExp(r'\s+'));
    final pts = <Offset>[];
    var i = 0;
    double n() => double.parse(t[i++].replaceAll(RegExp(r'^[MLC]'), ''));
    while (i < t.length) {
      final cmd = t[i][0];
      if (t[i].length == 1) i++;
      if (cmd == 'M' || cmd == 'L') {
        final x = n(), y = n();
        pts.add(Offset(x, y));
      } else if (cmd == 'C') {
        final cx = n(), cy = n(), rx = n(), ry = n(), a0 = n(), a1 = n();
        final steps = math.max(2, ((a1 - a0).abs() / 10).ceil());
        for (var k = 0; k <= steps; k++) {
          final a = (a0 + (a1 - a0) * k / steps) * math.pi / 180;
          pts.add(Offset(cx + rx * math.cos(a), cy + ry * math.sin(a)));
        }
      } else {
        throw FormatException('stroke: $part');
      }
    }
    out.add(pts);
  }
  return out;
}

/// 0–10 kutusundaki çizgileri ekrandaki harf kutusuna oturtur. Kalın yazıda
/// çizgi ortası kenardan yarım kalınlık içeride olduğu için kutu [inset]
/// kadar daraltılır (dar harflerde ortaya çöker).
List<List<Offset>> fitStrokes(List<List<Offset>> s, Rect box, {double inset = 11}) {
  final ix = math.min(inset, box.width / 2), iy = math.min(inset, box.height / 2);
  final r = Rect.fromLTRB(box.left + ix, box.top + iy, box.right - ix, box.bottom - iy);
  return [
    for (final st in s) [for (final p in st) Offset(r.left + p.dx / 10 * r.width, r.top + p.dy / 10 * r.height)]
  ];
}

/// Çizgi boyunca yaklaşık [step] aralıklı örnek noktalar.
List<Offset> samplePath(List<Offset> pts, {double step = 4}) {
  if (pts.isEmpty) return const [];
  final out = <Offset>[pts.first];
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = (b - a).distance;
    final n = math.max(1, (d / step).ceil());
    for (var k = 1; k <= n; k++) {
      out.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return out;
}

double pathLength(List<Offset> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += (pts[i] - pts[i - 1]).distance;
  }
  return l;
}

/// Çizgi üzerinde 0–1 oranındaki nokta ve o noktadaki yön.
(Offset, Offset) pointAlong(List<Offset> pts, double f) {
  if (pts.length < 2) return (pts.isEmpty ? Offset.zero : pts.first, const Offset(1, 0));
  final total = pathLength(pts);
  var want = clamp01(f) * total;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = (b - a).distance;
    if (want <= d || i == pts.length - 1) {
      final t = d == 0 ? 0.0 : clamp01(want / d);
      final dir = d == 0 ? const Offset(1, 0) : (b - a) / d;
      return (Offset.lerp(a, b, t)!, dir);
    }
    want -= d;
  }
  return (pts.last, const Offset(1, 0));
}

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
