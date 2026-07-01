/// Genre de destinataire d'un message reçu / émis (calque du `to.kind` du
/// contrat JSON serveur).
enum RecipientKind {
  /// Diffusion à tout le monde.
  all,

  /// Vers les postes centraux (émis par un poste portable).
  centrals,

  /// Adressé à une équipe précise ([MessageRecipient.name]).
  team,
}

/// Destinataire d'un message, pour situer l'émission/réception côté app
/// (« → TOUT LE MONDE » / « → POSTES CENTRAUX » / « → ÉQUIPE LYNX » / « → VOUS »).
/// `null` sur un message sans adressage (démo / ancien contrat).
class MessageRecipient {
  const MessageRecipient({required this.kind, this.name, this.self = false});

  final RecipientKind kind;

  /// Nom de l'équipe visée quand [kind] == [RecipientKind.team].
  final String? name;

  /// `true` quand la cible est le **poste courant** (→ affiché « VOUS »).
  final bool self;

  @override
  bool operator ==(Object other) =>
      other is MessageRecipient &&
      other.kind == kind &&
      other.name == name &&
      other.self == self;

  @override
  int get hashCode => Object.hash(kind, name, self);
}
