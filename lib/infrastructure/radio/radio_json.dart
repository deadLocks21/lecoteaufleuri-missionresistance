import '../../domain/entities/radio_message.dart';
import '../../domain/value_objects/message_id.dart';

/// (Dé)sérialisation des messages radio — contrat JSON partagé avec l'API
/// (`{ id, sender, sentAt, durationMs }`). L'`audioUrl` n'est **pas** transmise
/// par le backend : on la dérive de l'id (endpoint de flux proxy kDrive).

/// Sous-titre neutre des messages reçus (le backend ne porte pas de « flavor »
/// ; même esprit que les sous-titres en dur de `demo_data.dart`).
const String _incomingSubtitle = 'Transmission vocale';

/// Construit un [RadioMessage] reçu. [audioBase] = `<baseUrl>/sessions/<team>/radio`
/// ; l'URL audio est alors `<audioBase>/<id>/audio`.
RadioMessage radioMessageFromJson(
  Map<String, dynamic> json, {
  required String audioBase,
}) {
  final id = json['id'] as String;
  return RadioMessage(
    id: MessageId(id),
    sender: json['sender'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
    duration: Duration(milliseconds: (json['durationMs'] as num).round()),
    subtitle: _incomingSubtitle,
    audioUrl: '$audioBase/$id/audio',
  );
}

/// Liste reçue (déjà triée récent → ancien côté API).
List<RadioMessage> radioMessagesFromJson(
  List<dynamic> json, {
  required String audioBase,
}) =>
    [
      for (final item in json)
        radioMessageFromJson(item as Map<String, dynamic>, audioBase: audioBase),
    ];
