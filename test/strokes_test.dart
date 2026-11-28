import 'dart:ui';

import 'package:egitici_motoru/src/kinds/strokes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Harf İzleme çizgi verisi: her harf ayrıştırılır, 0–10 kutusunda kalır', () {
    for (final e in kStrokeSpec.entries) {
      final s = strokesFor(e.key)!;
      expect(s, isNotEmpty, reason: e.key);
      for (final st in s) {
        expect(st.length, greaterThanOrEqualTo(2), reason: e.key);
        for (final p in st) {
          expect(p.dx, inInclusiveRange(-0.6, 10.6), reason: e.key);
          expect(p.dy, inInclusiveRange(-0.6, 10.6), reason: e.key);
        }
      }
    }
    for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('')) {
      expect(kStrokeSpec.containsKey(c), isTrue, reason: c);
    }
  });

  test('çizgiler harf kutusuna oturtulur ve boyunca örneklenir', () {
    final f = fitStrokes(strokesFor('L')!, const Rect.fromLTWH(50, 20, 100, 160));
    expect(f.first.first.dx, closeTo(61, 0.01));
    expect(f.first.last.dy, closeTo(169, 0.01));
    expect(samplePath(f.first, step: 5).length, greaterThan(20));
    final (p, d) = pointAlong(f.first, 1.0);
    expect((p - f.first.last).distance, lessThan(0.01));
    expect(d.dx, greaterThan(0.9));
  });
}
