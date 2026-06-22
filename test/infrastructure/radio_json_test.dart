import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/domain/entities/radio_message.dart';
import 'package:mission_resistance/infrastructure/radio/radio_json.dart';

/// Verrouille le **contrat JSON** des messages radio partagé avec l'API
/// (`{ id, sender, sentAt, durationMs }`) et la dérivation de l'`audioUrl`.
/// Si l'un des deux côtés renomme un champ, ce test casse.
void main() {
  const audioBase = 'https://api.example/sessions/team-1/radio';

  group('radioMessagesFromJson', () {
    test('mappe les champs de l’API et dérive audioUrl depuis l’id', () {
      final messages = radioMessagesFromJson(
        [
          {
            'id': 'abc-123',
            'sender': 'Les bleus',
            'sentAt': '2026-06-21T17:20:34.082Z',
            'durationMs': 4200,
          },
        ],
        audioBase: audioBase,
      );

      expect(messages, hasLength(1));
      final m = messages.single;
      expect(m.id.value, 'abc-123');
      expect(m.sender, 'Les bleus');
      expect(m.duration, const Duration(milliseconds: 4200));
      expect(m.audioUrl, '$audioBase/abc-123/audio');
      // Un message reçu est non lu par défaut, et n'est pas « mine ».
      expect(m.status, MessageStatus.unread);
      expect(m.mine, isFalse);
      // `sentAt` (UTC côté API) est ramené à l'heure locale sans dériver.
      expect(m.sentAt.toUtc(), DateTime.utc(2026, 6, 21, 17, 20, 34, 82));
    });

    test('un message « mine » est marqué émis et déjà entendu', () {
      final m = radioMessagesFromJson(
        [
          {
            'id': 'own-1',
            'sender': 'Les bleus',
            'sentAt': '2026-06-21T18:39:07.581Z',
            'durationMs': 6163,
            'mine': true,
          },
        ],
        audioBase: audioBase,
      ).single;
      expect(m.mine, isTrue);
      expect(m.status, MessageStatus.heard);
      expect(m.audioUrl, '$audioBase/own-1/audio');
    });

    test('liste vide → aucune tuile', () {
      expect(radioMessagesFromJson(const [], audioBase: audioBase), isEmpty);
    });
  });
}
