import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/domain/exceptions/domain_exception.dart';
import 'package:mission_resistance/domain/value_objects/access_code.dart';
import 'package:mission_resistance/domain/value_objects/emission_level.dart';
import 'package:mission_resistance/domain/value_objects/mission_progress.dart';

void main() {
  group('AccessCode', () {
    test('compare après trim et insensible à la casse', () {
      expect(AccessCode('6450'), AccessCode(' 6450 '));
      expect(AccessCode('Renard'), AccessCode('renard'));
    });

    test('rejette une saisie vide', () {
      expect(() => AccessCode('   '), throwsA(isA<EmptyCodeException>()));
    });

    test('isBlank détecte une saisie vide', () {
      expect(AccessCode.isBlank('   '), isTrue);
      expect(AccessCode.isBlank('6450'), isFalse);
    });
  });

  group('EmissionLevel', () {
    test('convertit la valeur en angle (v*10 − 50)', () {
      expect(const EmissionLevel(0).angleDegrees, -50);
      expect(const EmissionLevel(5).angleDegrees, 0);
      expect(const EmissionLevel(10).angleDegrees, 50);
    });

    test('le repos est à −46°', () {
      expect(EmissionLevel.rest.angleDegrees, closeTo(-46, 0.0001));
    });
  });

  group('MissionProgress', () {
    test('état de démo : mission 2 en cours, 0 indice', () {
      final progress = MissionProgress.demo();
      expect(progress.currentMission, 1);
      expect(progress.unlocked, [2, 0, 0, 0]);
      expect(progress.unlockedForCurrent, 0);
    });

    test('decipherCurrent incrémente la mission courante uniquement', () {
      final next = MissionProgress.demo().decipherCurrent();
      expect(next.unlocked, [2, 1, 0, 0]);
    });

    test('toggleFlip replie puis re-révèle', () {
      var progress = MissionProgress.demo();
      expect(progress.isFlipped(1, 0), isFalse);
      progress = progress.toggleFlip(1, 0);
      expect(progress.isFlipped(1, 0), isTrue);
      progress = progress.toggleFlip(1, 0);
      expect(progress.isFlipped(1, 0), isFalse);
    });

    test('advanceMission passe à la mission suivante', () {
      expect(MissionProgress.demo().advanceMission().currentMission, 2);
    });
  });
}
