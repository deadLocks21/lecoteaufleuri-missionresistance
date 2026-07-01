import '../value_objects/message_id.dart';
import '../value_objects/message_recipient.dart';

/// Statut d'un message reçu (BRIEF §8.2).
enum MessageStatus {
  /// Non lu : badge `NOUVEAU`, voyant ambre.
  unread,

  /// Chargement du clip (buffering) : spinner, en attente du début réel de
  /// la lecture. Évite d'afficher l'égaliseur avant que le son ne démarre.
  loading,

  /// En cours de lecture : égaliseur animé, durée/▶ masqués.
  playing,

  /// Déjà écouté : badge `↺ réécouter`, voyant éteint, réécoutable à volonté.
  heard,
}

/// Message radio reçu d'un autre poste / du QG, ou **émis par ce poste**
/// (`mine`). Trié récent → ancien.
class RadioMessage {
  const RadioMessage({
    required this.id,
    required this.sender,
    required this.sentAt,
    required this.duration,
    required this.subtitle,
    this.audioUrl,
    this.status = MessageStatus.unread,
    this.mine = false,
    this.recipient,
  });

  final MessageId id;

  /// Expéditeur affiché en MAJ (ex. `QG CENTRAL`, `ÉQUIPE LYNX`).
  final String sender;

  final DateTime sentAt;
  final Duration duration;
  final String subtitle;

  /// URL du clip audio (null tant que l'émission/réception est simulée).
  final String? audioUrl;

  final MessageStatus status;

  /// `true` si ce message a été émis par ce poste : affiché « ÉMIS »
  /// (confirmation d'envoi) plutôt que reçu d'un autre poste du groupe.
  final bool mine;

  /// Destinataire du message (« → TOUT LE MONDE » / « → POSTES CENTRAUX » /
  /// « → ÉQUIPE X » / « → VOUS »). `null` = pas d'adressage (démo / ancien
  /// contrat).
  final MessageRecipient? recipient;

  bool get isUnread => status == MessageStatus.unread;
  bool get isLoading => status == MessageStatus.loading;
  bool get isPlaying => status == MessageStatus.playing;

  /// `true` tant que la lecture est en cours (chargement **ou** son actif) :
  /// la tuile n'est pas re-déclenchable.
  bool get isActive => isLoading || isPlaying;
  bool get isHeard => status == MessageStatus.heard;

  RadioMessage copyWith({MessageStatus? status}) {
    return RadioMessage(
      id: id,
      sender: sender,
      sentAt: sentAt,
      duration: duration,
      subtitle: subtitle,
      audioUrl: audioUrl,
      status: status ?? this.status,
      mine: mine,
      recipient: recipient,
    );
  }
}
