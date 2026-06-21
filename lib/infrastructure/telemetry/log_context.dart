/// Sac d'attributs d'identité transverses attachés à chaque enregistrement de
/// log via le resolver dynamique de [LoggerService].
///
/// Tenu par un seul provider stable sur toute la vie de l'app :
///
/// - [sessionId] est fixé à la construction (un par lancement) — toutes les
///   lignes de log d'un même run le partagent, donc une session est
///   reconstructible dans Signoz en filtrant sur `session.id`.
///
/// Pas de `device.id` persistant ici : l'app est en mémoire seule (pas de
/// stockage), l'identité se limite donc à la session du lancement courant.
class LogContext {
  final String sessionId;

  const LogContext({required this.sessionId});

  Map<String, Object?> toAttributes() => {
        'session.id': sessionId,
      };
}
