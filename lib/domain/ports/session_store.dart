import '../value_objects/stored_session.dart';

/// Persistance locale de la session (jumeau réel = `shared_preferences`).
/// Permet de ne pas redemander le code à chaque lancement.
abstract interface class SessionStore {
  /// Session mémorisée, ou `null` (premier lancement / après déconnexion).
  Future<StoredSession?> load();

  /// Mémorise la session après un login réussi.
  Future<void> save(StoredSession session);

  /// Efface la session (déconnexion).
  Future<void> clear();
}
