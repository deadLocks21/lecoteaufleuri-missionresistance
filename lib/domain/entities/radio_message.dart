import '../value_objects/message_id.dart';

/// Statut d'un message reçu (BRIEF §8.2).
enum MessageStatus {
  /// Non lu : badge `NOUVEAU`, voyant ambre.
  unread,

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

  bool get isUnread => status == MessageStatus.unread;
  bool get isPlaying => status == MessageStatus.playing;
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
    );
  }
}
