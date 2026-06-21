import '../../domain/ports/logger_port.dart';
import '../../domain/value_objects/log_level.dart';

/// Diffuse chaque enregistrement vers une liste de [LoggerPort].
///
/// Cas d'usage principal : en build debug avec une clé Signoz configurée,
/// envelopper à la fois le `ConsoleLogger` et le `SignozLogger` pour que le dev
/// voie dans sa console *exactement* ce qui est expédié sur le réseau. Supprime
/// l'écart entre « ce que je vois en local » et « ce qui arrive dans Signoz ».
///
/// Les appels aux enfants sont séquentiels (`await` chacun) — le volume est
/// assez faible pour que le fan-out parallèle soit prématuré, et le séquentiel
/// rend l'ordre déterministe dans la console.
///
/// Si un enfant lève (ce qu'il ne devrait pas, par contrat [LoggerPort], mais
/// par défense), l'erreur est avalée pour qu'un adapter défaillant ne fasse pas
/// tomber les autres.
class CompositeLogger implements LoggerPort {
  final List<LoggerPort> _children;

  CompositeLogger(List<LoggerPort> children)
      : assert(
          children.isNotEmpty,
          'CompositeLogger a besoin d\'au moins un enfant',
        ),
        _children = List.unmodifiable(children);

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    for (final child in _children) {
      try {
        await child.log(
          level,
          message,
          attributes: attributes,
          error: error,
          stack: stack,
        );
      } catch (_) {
        // Avalé — un mauvais adapter ne doit pas réduire les autres au silence.
      }
    }
  }

  @override
  Future<void> flush() async {
    for (final child in _children) {
      try {
        await child.flush();
      } catch (_) {
        // Idem ci-dessus.
      }
    }
  }
}
