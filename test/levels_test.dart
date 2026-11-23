import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:egitici_motoru/egitici_motoru.dart';

void main() {
  test('27 tür', () => expect(kEgiticiKinds.length, 27));

  for (final e in kEgiticiKinds.entries) {
    test('${e.key}: bölümler kurulur ve doğrulanır', () {
      final rules = egiticiRulesFor('oyun-test-${e.key}', e.key);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      for (final n in const [1, 2, 7, 40, 300, 5000, 99999]) {
        expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: '${e.key} $n');
      }
    });
  }
}
