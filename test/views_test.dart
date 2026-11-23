import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:egitici_motoru/egitici_motoru.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';

PlayContext fakeCtx(GeneratedLevel gl, String lang, List<RoundResult> results) => PlayContext(
      spec: gl.spec,
      generated: gl,
      resume: const {},
      pieceColors: const [Color(0xFF3E6FB0), Color(0xFFC8553D), Color(0xFF4F9A6E)],
      background: const [Color(0xFF203040), Color(0xFF304050)],
      colorBlind: false,
      reducedMotion: false,
      leftHanded: false,
      lang: lang,
      t: (k, [p = const {}]) => k,
      finish: results.add,
      saveResume: (_) {},
      requestHint: () async => true,
      requestBooster: () async => true,
      requestContinue: () async => false,
      sfx: (_) {},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final e in kEgiticiKinds.entries) {
    for (final lang in const ['tr', 'en', 'ar']) {
      testWidgets('${e.key} ($lang): ekran açılır, dokunuşlara dayanır', (tester) async {
        tester.view.physicalSize = const Size(1080, 2280);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        final rules = egiticiRulesFor('oyun-test-${e.key}', e.key);
        final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
        final gl = rules.build(planner.spec(5));
        final results = <RoundResult>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SafeArea(child: EgiticiStage(ctx: fakeCtx(gl, lang, results), rules: rules))),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (var y = 70.0; y < size.height - 10; y += size.height / 9) {
          for (var x = 20.0; x < size.width; x += size.width / 6) {
            await tester.tapAt(Offset(x, y));
            await tester.pump(const Duration(milliseconds: 120));
            if (find.byType(Dialog).evaluate().isNotEmpty || find.byType(AlertDialog).evaluate().isNotEmpty) {
              await tester.tapAt(const Offset(5, 5));
              await tester.pump(const Duration(milliseconds: 300));
            }
          }
        }
        await tester.dragFrom(Offset(size.width * 0.5, size.height * 0.8), Offset(-size.width * 0.2, -size.height * 0.4));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }

  testWidgets('çıkartma albümü ve ebeveyn kapısı açılır', (tester) async {
    final rules = egiticiRulesFor('oyun-test-sayi', 'sayi');
    final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
    final gl = rules.build(planner.spec(3));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EgiticiStage(ctx: fakeCtx(gl, 'tr', []), rules: rules))));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.auto_stories));
    await tester.pumpAndSettle();
    expect(find.text('Çıkartma albümü'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.text('Bir yetişkine sor'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
