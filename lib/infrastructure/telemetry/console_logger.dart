import 'package:flutter/foundation.dart';

import '../../domain/ports/logger_port.dart';
import '../../domain/value_objects/log_level.dart';

/// [LoggerPort] qui imprime dans la console via [debugPrint].
///
/// Utilisé :
/// - Dans tout build non-release comme puits principal.
/// - Comme une branche de `CompositeLogger` pour que le dev voie dans sa
///   console exactement ce qui part vers Signoz (calibrage).
///
/// [debugPrint] est choisi à dessein plutôt que `dart:developer log()` : c'est
/// le canal qui apparaît réellement dans le terminal `flutter run` et dans
/// `adb logcat`. Le throttling de [debugPrint] évite aussi que logcat ne perde
/// des lignes sous charge.
///
/// Une ligne par enregistrement : `LEVEL message k=v k=v …`, suivie de la
/// stack trace si présente. Léger et grep-friendly.
///
/// Sans tampon — `flush()` est un no-op.
class ConsoleLogger implements LoggerPort {
  /// Préfixe optionnel devant le message. Utile pour distinguer les
  /// enregistrements qui sont *aussi* partis vers Signoz quand ce service est
  /// enveloppé dans un `CompositeLogger` (ex. `[→signoz]`).
  final String? prefix;

  const ConsoleLogger({this.prefix});

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    final buf = StringBuffer();
    if (prefix != null) buf.write('$prefix ');
    // Le niveau fait partie du texte puisque debugPrint n'a pas de param de
    // sévérité.
    buf.write('${level.otelSeverityText} ');
    buf.write(message);
    if (attributes.isNotEmpty) {
      buf.write(' ');
      buf.writeAll(
        attributes.entries.map((e) => '${e.key}=${_format(e.value)}'),
        ' ',
      );
    }
    if (error != null) buf.write(' error=${_format(error)}');
    debugPrint(buf.toString());
    if (stack != null) debugPrint(stack.toString());
  }

  @override
  Future<void> flush() async {}

  String _format(Object? v) {
    if (v == null) return 'null';
    if (v is String) {
      // Guillemets seulement si la valeur contient un espace, sinon la ligne
      // reste maximalement grep-friendly.
      return v.contains(RegExp(r'\s')) ? '"$v"' : v;
    }
    return v.toString();
  }
}
