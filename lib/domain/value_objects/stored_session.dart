/// Session mémorisée localement (shared preferences) : permet la **reconnexion
/// automatique** au lancement sans redemander le code (BRIEF §13 — « on ne
/// redemande pas »). On conserve le **code** (saisi une fois) et l'identité
/// d'équipe (`id` pour le suivi GPS, `name` affiché immédiatement, hors-ligne).
///
/// On mémorise aussi le **dernier id de partie connu** ([partieId], `null` si
/// aucune au login) : il sert d'amorce à l'en-tête `X-Partie-Id` au lancement,
/// avant que le poll de partie ne réconcilie l'état réel.
class StoredSession {
  const StoredSession({
    required this.code,
    required this.teamId,
    required this.teamName,
    this.partieId,
  });

  final String code;
  final String teamId;
  final String teamName;
  final String? partieId;
}
