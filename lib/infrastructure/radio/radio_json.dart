import '../../domain/entities/radio_message.dart';
import '../../domain/value_objects/message_id.dart';

/// (Dé)sérialisation des messages radio — contrat JSON partagé avec l'API
/// (`{ id, sender, sentAt, durationMs, mine }`). L'`audioUrl` n'est **pas**
/// transmise par le backend : on la dérive de l'id (endpoint de flux proxy
/// kDrive).

/// Sous-titres neutres (le backend ne porte pas de « flavor » ; même esprit que
/// les sous-titres en dur de `demo_data.dart`).
const String _incomingSubtitle = 'Transmission vocale';
const String _ownSubtitle = 'Votre transmission';

/// Construit un [RadioMessage]. [audioBase] = `<baseUrl>/sessions/<team>/radio`
/// ; l'URL audio est alors `<audioBase>/<id>/audio`. Un message `mine` (émis par
/// ce poste) est affiché « ÉMIS » et déjà « entendu » (pas de voyant « nouveau »).
RadioMessage radioMessageFromJson(
  Map<String, dynamic> json, {
  required String audioBase,
}) {
  final id = json['id'] as String;
  final mine = json['mine'] == true;
  return RadioMessage(
    id: MessageId(id),
    sender: json['sender'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
    duration: Duration(milliseconds: (json['durationMs'] as num).round()),
    subtitle: mine ? _ownSubtitle : _incomingSubtitle,
    audioUrl: '$audioBase/$id/audio',
    status: mine ? MessageStatus.heard : MessageStatus.unread,
    mine: mine,
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
