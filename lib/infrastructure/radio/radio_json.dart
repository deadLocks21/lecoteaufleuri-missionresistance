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

/// Clé d'évènement transportée à l'isolate UI via `sendDataToMain` (à côté de
/// l'évènement `fix` du suivi GPS).
const String kRadioMessageEvent = 'radio';

/// Sérialise un [RadioMessage] pour le passage **isolate de fond → isolate UI**
/// (`sendDataToMain` n'accepte que des primitives). On transporte l'`audioUrl`
/// déjà dérivée plutôt que de la recalculer côté UI.
Map<String, Object?> radioMessageToData(RadioMessage message) => {
      'event': kRadioMessageEvent,
      'id': message.id.value,
      'sender': message.sender,
      'sentAt': message.sentAt.toIso8601String(),
      'durationMs': message.duration.inMilliseconds,
      'subtitle': message.subtitle,
      'audioUrl': message.audioUrl,
      'status': message.status.name,
      'mine': message.mine,
    };

/// Reconstruit un [RadioMessage] côté UI depuis la charge de [radioMessageToData].
RadioMessage radioMessageFromData(Map<dynamic, dynamic> data) => RadioMessage(
      id: MessageId(data['id'] as String),
      sender: data['sender'] as String,
      sentAt: DateTime.parse(data['sentAt'] as String),
      duration: Duration(milliseconds: (data['durationMs'] as num).round()),
      subtitle: data['subtitle'] as String,
      audioUrl: data['audioUrl'] as String?,
      status: MessageStatus.values.byName(data['status'] as String),
      mine: data['mine'] == true,
    );
