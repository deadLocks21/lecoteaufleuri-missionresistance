/// Session mémorisée localement (shared preferences) : permet la **reconnexion
/// automatique** au lancement sans redemander le code (BRIEF §13 — « on ne
/// redemande pas »). On conserve le **code** (saisi une fois) et l'identité
/// d'équipe (`id` pour le suivi GPS, `name` affiché immédiatement, hors-ligne).
class StoredSession {
  const StoredSession({
    required this.code,
    required this.teamId,
    required this.teamName,
  });

  final String code;
  final String teamId;
  final String teamName;
}
