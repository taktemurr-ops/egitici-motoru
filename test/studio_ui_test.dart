// Onaylı tasarım: çocuk çerçevesi, albüm, ebeveyn kapısı ve ebeveyn alanı
// koyu palette okunur; her tür merkez benzeri ev sahibinde okunur açılır.
import 'package:egitici_motoru/egitici_motoru.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio_core/core/level_plan.dart';

import 'studio_readability.dart';
import 'views_test.dart' show fakeCtx;

Widget stageFor(String kind, String lang) {
  final rules = egiticiRulesFor('oyun-test-$kind', kind);
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
  final gl = rules.build(planner.spec(5));
  return EgiticiStage(ctx: fakeCtx(gl, lang, []), rules: rules);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  for (final kind in kEgiticiKinds.keys) {
    testWidgets('$kind: koyu palette yazılar okunur', (tester) async {
      phone(tester);
      await tester.pumpWidget(studioHost(stageFor(kind, 'tr')));
      await tester.pump(const Duration(milliseconds: 400));
      expectReadable(tester, where: kind);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('albüm, ebeveyn kapısı ve ebeveyn alanı onaylı tasarımda', (tester) async {
    phone(tester);
    final kind = kEgiticiKinds.keys.first;
    await tester.pumpWidget(studioHost(stageFor(kind, 'tr')));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip(et('tr', 'stickers')));
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expectReadable(tester, where: 'albüm');
    await tester.tap(find.byTooltip(et('tr', 'close')).last);
    await settle(tester);

    await tester.tap(find.byTooltip(et('tr', 'parents')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expectReadable(tester, where: 'ebeveyn kapısı');
    // Doğru cevabı bul ve gir: ebeveyn alanı açılır.
    final q = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere((s) => s.contains('×'));
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    final answer = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    await tester.tap(find.widgetWithText(OutlinedButton, '$answer'));
    await settle(tester);
    expect(find.byType(TabBar), findsOneWidget);
    expectReadable(tester, where: 'ebeveyn raporu');
    await tester.tap(find.byIcon(Icons.tune));
    await settle(tester);
    expectReadable(tester, where: 'ebeveyn ayarları');
    await tester.tap(find.byTooltip(et('tr', 'close')).last);
    await settle(tester);
    expect(find.byType(TabBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('dinlenme ekranı (uyku saati) okunur, ebeveyn düğmesi kapıya gider', (tester) async {
    phone(tester);
    final s = KidStore.instance;
    await s.load();
    s.bedtimeOn = true;
    s.bedFrom = 0;
    s.bedTo = 24;
    addTearDown(() => s.bedtimeOn = false);
    await tester.pumpWidget(studioHost(stageFor(kEgiticiKinds.keys.first, 'ar')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🌙'), findsOneWidget);
    expectReadable(tester, where: 'dinlenme');
    await tester.tap(find.text(et('ar', 'parents')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(et('ar', 'cancel')));
    await settle(tester);
    s.bedtimeOn = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
