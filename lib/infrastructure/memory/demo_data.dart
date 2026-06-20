import '../../domain/entities/mission.dart';
import '../../domain/entities/radio_message.dart';
import '../../domain/entities/scenario.dart';
import '../../domain/value_objects/message_id.dart';

/// Données de démo en dur (BRIEF §8.2 & §10) servies par les jumeaux InMemory.
abstract final class DemoData {
  /// Scénario des 4 missions (ordre = ordre de déverrouillage).
  static Scenario scenario() => Scenario(
        missions: [
          Mission(index: 0, title: 'Établir le contact', clues: [
            const Clue(index: 0, text: 'Le QG émet sur la fréquence du clocher.'),
            const Clue(index: 1, text: 'Comptez les coups de cloche à midi.'),
          ]),
          Mission(index: 1, title: 'Décoder le message', clues: [
            const Clue(index: 0, text: 'La clé change chaque jour.'),
            const Clue(index: 1, text: 'Le premier mot est le nom du village.'),
            const Clue(index: 2, text: 'Décalez chaque lettre de trois rangs.'),
          ]),
          Mission(index: 2, title: 'Trouver la cache', clues: [
            const Clue(index: 0, text: "Cherchez près de l'ancien lavoir."),
            const Clue(index: 1, text: 'Sous la troisième pierre du muret.'),
          ]),
          Mission(index: 3, title: 'Transmettre le code', clues: [
            const Clue(index: 0, text: 'Émettez à 14 h 00 précises.'),
            const Clue(index: 1, text: 'Indicatif d\'appel : RENARD-2.'),
          ]),
        ],
      );

  /// 3 messages de démo, du plus récent au plus ancien (BRIEF §8.2).
  /// La date est décorative (le poste n'affiche que l'heure HH:mm).
  static List<RadioMessage> messages() {
    DateTime at(int h, int m) => DateTime(1944, 6, 6, h, m);
    return [
      RadioMessage(
        id: const MessageId('m1'),
        sender: 'QG CENTRAL',
        sentAt: at(12, 42),
        duration: const Duration(seconds: 21),
        subtitle: 'Repli immédiat — toucher pour écouter',
      ),
      RadioMessage(
        id: const MessageId('m2'),
        sender: 'ÉQUIPE LYNX',
        sentAt: at(12, 18),
        duration: const Duration(seconds: 8),
        subtitle: "Position de l'ennemi signalée",
      ),
      RadioMessage(
        id: const MessageId('m3'),
        sender: 'QG CENTRAL',
        sentAt: at(11, 55),
        duration: const Duration(seconds: 14),
        subtitle: 'Ordre de mission initial',
        status: MessageStatus.heard,
      ),
    ];
  }
}
