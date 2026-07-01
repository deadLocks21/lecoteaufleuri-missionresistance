import 'recipient.dart';

/// État radio du poste courant (cf. `GET /sessions/:team/radio/status`), en deux
/// volets :
///
/// - **coupe-radio** : la régie peut couper la radio d'une partie (« le poste
///   central est tombé aux mains des Allemands ») — l'émission est alors refusée à
///   tous **sauf** les `nazis` ;
/// - **adressage** : un poste central / nazi **choisit** son destinataire
///   ([canAddress] + [recipients]) ; un poste portable n'en choisit pas (il émet
///   toujours vers les postes centraux).
class RadioGate {
  const RadioGate({
    required this.blocked,
    required this.canSend,
    this.canAddress = false,
    this.recipients = const [],
  });

  /// La régie a coupé la radio de la partie en cours.
  final bool blocked;

  /// Ce poste peut encore émettre : vrai quand la radio n'est pas coupée, et
  /// toujours vrai pour les `nazis` (qui « tiennent » le poste central).
  final bool canSend;

  /// Ce poste **choisit** son destinataire (poste central / nazi). Faux pour un
  /// portable, qui émet toujours vers les postes centraux.
  final bool canAddress;

  /// Équipes ciblables du groupe (vide quand [canAddress] est faux).
  final List<Recipient> recipients;

  /// Radio ouverte, sans adressage (défaut hors-ligne / démo).
  static const open = RadioGate(blocked: false, canSend: true);

  /// `true` quand l'émission doit être **refusée** à ce poste (radio coupée et
  /// poste non exempté) → bandeau d'alerte + bouton TRANSMETTRE grisé.
  bool get emissionDenied => blocked && !canSend;

  @override
  bool operator ==(Object other) =>
      other is RadioGate &&
      other.blocked == blocked &&
      other.canSend == canSend &&
      other.canAddress == canAddress &&
      _sameRecipients(other.recipients, recipients);

  @override
  int get hashCode =>
      Object.hash(blocked, canSend, canAddress, Object.hashAll(recipients));

  static bool _sameRecipients(List<Recipient> a, List<Recipient> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
