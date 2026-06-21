import '../../domain/ports/logger_port.dart';
import '../../domain/value_objects/log_level.dart';

/// Façade ergonomique au-dessus d'un [LoggerPort].
///
/// Deux raisons d'exister plutôt que d'appeler [LoggerPort] directement :
///
/// 1. **Sucre** — `logger.info('foo')` se lit mieux que
///    `logger.log(LogLevel.info, 'foo')` et garde le code des services propre.
/// 2. **Propagation de contexte** — chaque enregistrement est enrichi d'un sac
///    d'attributs contextuels fusionnés avec ce que fournit l'appelant. Les
///    sites d'appel ne portent que des clés métier ; le contexte transverse
///    est centralisé ici.
///
/// ## Trois couches de contexte
///
/// À l'émission, les attributs sont fusionnés dans cet ordre (les couches
/// suivantes écrasent les précédentes en cas de collision de clé) :
///
/// 1. **Contexte dynamique** — produit par [resolveContext], un callback qui
///    renvoie les attributs d'identité *courants* (`session.id`…). Réévalué à
///    chaque émission pour que l'instance du logger reste stable. Câblé par le
///    provider ; la couche application reste sans Riverpod.
/// 2. **Contexte statique** — attributs attachés via [withContext], pour
///    scoper tous les logs d'une unité de travail.
/// 3. **Attributs du site d'appel** — ce que passe l'appelant à
///    `info`/`error`/… Le plus spécifique, gagne toujours.
class LoggerService {
  final LoggerPort _logger;
  final Map<String, Object?> _staticContext;
  final Map<String, Object?> Function()? _resolveContext;

  const LoggerService(
    this._logger, {
    Map<String, Object?> context = const {},
    Map<String, Object?> Function()? resolveContext,
  })  : _staticContext = context,
        _resolveContext = resolveContext;

  /// Renvoie une nouvelle façade qui ajoute [extra] par-dessus le contexte
  /// statique courant. Le [resolveContext] dynamique est préservé tel quel.
  LoggerService withContext(Map<String, Object?> extra) {
    if (extra.isEmpty) return this;
    return LoggerService(
      _logger,
      context: {..._staticContext, ...extra},
      resolveContext: _resolveContext,
    );
  }

  Future<void> debug(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.debug, message, attrs: attrs);

  Future<void> info(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.info, message, attrs: attrs);

  Future<void> warn(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) =>
      _emit(LogLevel.warn, message, attrs: attrs, error: error, stack: stack);

  Future<void> error(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) =>
      _emit(LogLevel.error, message, attrs: attrs, error: error, stack: stack);

  /// Vide le port sous-jacent. À appeler depuis les hooks de cycle de vie
  /// (pause / dispose) pour que le tampon en vol soit expédié avant que l'OS
  /// suspende le process.
  Future<void> flush() => _logger.flush();

  Future<void> _emit(
    LogLevel level,
    String message, {
    required Map<String, Object?> attrs,
    Object? error,
    StackTrace? stack,
  }) {
    // Les exceptions du resolver sont avalées : l'identité ne doit jamais
    // couler un log.
    Map<String, Object?> dynamic_;
    try {
      dynamic_ = _resolveContext?.call() ?? const {};
    } catch (_) {
      dynamic_ = const {};
    }
    final merged =
        (dynamic_.isEmpty && _staticContext.isEmpty && attrs.isEmpty)
            ? const <String, Object?>{}
            : <String, Object?>{...dynamic_, ..._staticContext, ...attrs};
    return _logger.log(
      level,
      message,
      attributes: merged,
      error: error,
      stack: stack,
    );
  }
}
