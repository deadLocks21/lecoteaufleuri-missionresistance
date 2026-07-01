/// État du **coupe-radio** pour le poste courant (cf. `GET /sessions/:team/radio/
/// status`). La régie peut couper la radio d'une partie (« le poste central est
/// tombé aux mains des Allemands ») : l'émission est alors refusée à tous les
/// postes **sauf** les `nazis`.
class RadioGate {
  const RadioGate({required this.blocked, required this.canSend});

  /// La régie a coupé la radio de la partie en cours.
  final bool blocked;

  /// Ce poste peut encore émettre : vrai quand la radio n'est pas coupée, et
  /// toujours vrai pour les `nazis` (qui « tiennent » le poste central).
  final bool canSend;

  /// Radio ouverte (défaut hors-ligne / démo) : tout le monde peut émettre.
  static const open = RadioGate(blocked: false, canSend: true);

  /// `true` quand l'émission doit être **refusée** à ce poste (radio coupée et
  /// poste non exempté) → bandeau d'alerte + bouton TRANSMETTRE grisé.
  bool get emissionDenied => blocked && !canSend;

  @override
  bool operator ==(Object other) =>
      other is RadioGate && other.blocked == blocked && other.canSend == canSend;

  @override
  int get hashCode => Object.hash(blocked, canSend);
}
