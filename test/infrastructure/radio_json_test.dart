import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/domain/entities/radio_message.dart';
import 'package:mission_resistance/domain/value_objects/message_id.dart';
import 'package:mission_resistance/domain/value_objects/message_recipient.dart';
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

    test('mappe le destinataire `to` (all / centrals / team + self)', () {
      RadioMessage parse(Object? to) => radioMessagesFromJson(
            [
              {
                'id': 'x',
                'sender': 'Les bleus',
                'sentAt': '2026-06-21T17:20:34.082Z',
                'durationMs': 1000,
                'to': ?to,
              },
            ],
            audioBase: audioBase,
          ).single;

      expect(parse({'kind': 'all'}).recipient?.kind, RecipientKind.all);
      expect(parse({'kind': 'centrals'}).recipient?.kind, RecipientKind.centrals);

      final team = parse({'kind': 'team', 'name': 'ÉQUIPE LYNX', 'self': true})
          .recipient;
      expect(team?.kind, RecipientKind.team);
      expect(team?.name, 'ÉQUIPE LYNX');
      expect(team?.self, isTrue);

      // Descripteur absent (démo / ancien contrat) → pas d'adressage.
      expect(parse(null).recipient, isNull);
    });
  });

  group('transport isolate de fond → UI', () {
    test('radioMessageToData/FromData fait un aller-retour sans perte', () {
      final original = RadioMessage(
        id: const MessageId('abc-123'),
        sender: 'QG CENTRAL',
        sentAt: DateTime.parse('2026-06-21T17:20:34.082Z'),
        duration: const Duration(milliseconds: 4200),
        subtitle: 'Transmission vocale',
        audioUrl: '$audioBase/abc-123/audio',
        status: MessageStatus.unread,
      );

      final data = radioMessageToData(original);
      expect(data['event'], kRadioMessageEvent); // discriminant côté UI
      final restored = radioMessageFromData(data);

      expect(restored.id.value, original.id.value);
      expect(restored.sender, original.sender);
      expect(restored.sentAt.toUtc(), original.sentAt.toUtc());
      expect(restored.duration, original.duration);
      expect(restored.subtitle, original.subtitle);
      expect(restored.audioUrl, original.audioUrl);
      expect(restored.status, original.status);
      expect(restored.mine, original.mine);
    });

    test('un message « mine » conserve son drapeau et son statut entendu', () {
      final mine = RadioMessage(
        id: const MessageId('own-1'),
        sender: 'LES RENARDS',
        sentAt: DateTime.parse('2026-06-21T18:39:07.581Z'),
        duration: const Duration(milliseconds: 6163),
        subtitle: 'Votre transmission',
        audioUrl: '$audioBase/own-1/audio',
        status: MessageStatus.heard,
        mine: true,
      );

      final restored = radioMessageFromData(radioMessageToData(mine));
      expect(restored.mine, isTrue);
      expect(restored.status, MessageStatus.heard);
    });

    test('le destinataire (équipe + nom + self) survit à l’aller-retour', () {
      final msg = RadioMessage(
        id: const MessageId('t-1'),
        sender: 'QG CENTRAL',
        sentAt: DateTime.parse('2026-06-21T17:20:34.082Z'),
        duration: const Duration(milliseconds: 4200),
        subtitle: 'Transmission vocale',
        recipient: const MessageRecipient(
          kind: RecipientKind.team,
          name: 'ÉQUIPE LYNX',
          self: true,
        ),
      );

      final restored = radioMessageFromData(radioMessageToData(msg));
      expect(restored.recipient?.kind, RecipientKind.team);
      expect(restored.recipient?.name, 'ÉQUIPE LYNX');
      expect(restored.recipient?.self, isTrue);
    });
  });
}
