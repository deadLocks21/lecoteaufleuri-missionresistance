import '../value_objects/log_level.dart';

/// Port d'émission des logs (concern transverse, ARCHITECTURE §6.5).
///
/// Les implémentations vivent dans `infrastructure/telemetry/` :
///
/// - `ConsoleLogger`   — affiche dans la console de dev.
/// - `SignozLogger`    — expédie les logs en OTLP/HTTP vers Signoz.
/// - `CompositeLogger` — diffuse vers plusieurs adapters à la fois (sert à
///   refléter le trafic Signoz dans la console pendant le calibrage).
///
/// Le contrat est volontairement minimal : un puits asynchrone. Les sucres
/// ergonomiques (`info`, `error`, attributs de contexte automatiques…) vivent
/// dans la couche application (`LoggerService`) pour que le port reste stable.
///
/// `attributes` : paires clé/valeur arbitraires attachées à l'enregistrement.
/// Les valeurs doivent être des primitives JSON (`String`, `num`, `bool`,
/// `null`) ; tout le reste est converti via `toString()` par l'adapter.
///
/// Une implémentation NE DOIT JAMAIS lever : un logger qui échoue doit
/// dégrader silencieusement (la télémétrie indisponible ne fait pas planter
/// l'app).
abstract interface class LoggerPort {
  /// Enregistre une entrée de log.
  ///
  /// [message] est le résumé lisible. Garde-le court et stable (bon :
  /// `emission.failed` ; mauvais : `Impossible d'émettre à 10:42`). Les
  /// données variables vont dans [attributes].
  ///
  /// [error] / [stack] sont optionnels et utilisés quand [level] vaut
  /// [LogLevel.error] (ou parfois [LogLevel.warn]) pour capturer le type
  /// d'exception et la stack trace.
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes,
    Object? error,
    StackTrace? stack,
  });

  /// Vide le tampon en cours. Appelé sur pause/dispose de l'app pour que les
  /// logs émis juste avant la mise en arrière-plan ne soient pas perdus.
  /// No-op pour les adapters qui ne bufferisent pas.
  Future<void> flush();
}
