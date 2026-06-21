import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../domain/ports/logger_port.dart';
import '../../domain/value_objects/log_level.dart';

/// Expédie les enregistrements de log vers une instance Signoz en OTLP/HTTP.
///
/// Format de fil : le payload JSON `ExportLogsServiceRequest` d'OpenTelemetry,
/// posté sur `<base ingest>/v1/logs`. Signoz accepte nativement l'encodage JSON
/// du protobuf, donc pas de SDK nécessaire — un corps fait main est plus léger
/// que de tirer `opentelemetry` + `opentelemetry_exporter_otlp_http`, encore
/// rugueux sur Dart.
///
/// ## Attributs de ressource
///
/// Chaque batch est étiqueté avec les [resourceAttributes] passés à la
/// construction (`service.name`, `service.version`, `deployment.environment`,
/// `os.type`…). Ils apparaissent en colonnes `resource.*` dans Signoz et sont
/// la façon recommandée de découper les dashboards.
///
/// ## Batching
///
/// Les enregistrements s'accumulent en mémoire et sont vidés :
/// - Dès que [maxBatchSize] est atteint.
/// - Sinon toutes les [flushInterval], par un timer périodique.
/// - Sur [flush] explicite (depuis les hooks de cycle de vie de l'app).
///
/// La liste est plafonnée à [maxQueueSize] pour éviter une croissance non
/// bornée quand le réseau reste coupé — les vieux enregistrements partent en
/// premier.
///
/// ## Mode d'échec
///
/// Les erreurs réseau sont attrapées et signalées via `dart:developer` (pas via
/// [LoggerPort], pour éviter la récursion). Le batch perdu n'est *pas* rejoué —
/// la télémétrie est best-effort, et une file de retry risquerait d'empiler des
/// doublons sur des échecs transitoires.
class SignozLogger implements LoggerPort {
  /// Endpoint OTLP HTTP complet, ex.
  /// `https://ingest.eu.signoz.cloud:443/v1/logs` (Signoz Cloud) ou
  /// `http://10.0.2.2:4318/v1/logs` (émulateur Android → collecteur Signoz
  /// self-hosted sur l'hôte).
  final String endpoint;

  /// Clé d'ingestion Cloud. Envoyée en header `signoz-access-token`.
  /// `null`/vide pour un self-hosted sans auth.
  final String? ingestionKey;

  /// Attributs de ressource OTLP attachés à chaque batch.
  final Map<String, Object?> resourceAttributes;

  final Dio _dio;
  final Duration flushInterval;
  final int maxBatchSize;
  final int maxQueueSize;

  final List<_PendingRecord> _buffer = [];
  Timer? _timer;
  bool _disposed = false;
  Future<void>? _inflight;

  SignozLogger({
    required this.endpoint,
    this.ingestionKey,
    this.resourceAttributes = const {},
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 50,
    this.maxQueueSize = 500,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                contentType: 'application/json',
                responseType: ResponseType.plain,
              ),
            ) {
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    if (_disposed) return;
    // Jette le plus vieux si plein — la donnée la plus récente est plus utile.
    if (_buffer.length >= maxQueueSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(
      _PendingRecord(
        timestampNanos: _nowUnixNano(),
        level: level,
        message: message,
        attributes: attributes,
        error: error,
        stack: stack,
      ),
    );
    if (_buffer.length >= maxBatchSize) {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() async {
    // Coalesce les flushes concurrents — une seule expédition à la fois.
    if (_inflight != null) return _inflight;
    if (_buffer.isEmpty) return;
    final batch = List<_PendingRecord>.from(_buffer);
    _buffer.clear();
    final future = _ship(batch);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _ship(List<_PendingRecord> batch) async {
    try {
      await _dio.post<dynamic>(
        endpoint,
        data: jsonEncode(_buildPayload(batch)),
        options: Options(
          headers: {
            if (ingestionKey != null && ingestionKey!.isNotEmpty)
              'signoz-access-token': ingestionKey,
          },
        ),
      );
    } catch (e, st) {
      // Ne jamais lever — la télémétrie ne doit pas faire planter l'app.
      // Remonte à la console de dev (pas à LoggerPort, ça récurserait).
      developer.log(
        'signoz: échec d\'expédition d\'un batch de ${batch.length} enreg. — abandon',
        name: 'mission_resistance.logger',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }
  }

  Map<String, dynamic> _buildPayload(List<_PendingRecord> batch) {
    return {
      'resourceLogs': [
        {
          'resource': {'attributes': _otlpAttributes(resourceAttributes)},
          'scopeLogs': [
            {
              'scope': {'name': 'mission_resistance.app'},
              'logRecords': batch.map(_otlpRecord).toList(growable: false),
            },
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _otlpRecord(_PendingRecord r) {
    final attrs = <String, Object?>{...r.attributes};
    if (r.error != null) {
      attrs['exception.type'] = r.error.runtimeType.toString();
      attrs['exception.message'] = r.error.toString();
    }
    if (r.stack != null) {
      attrs['exception.stacktrace'] = r.stack.toString();
    }
    return {
      'timeUnixNano': r.timestampNanos.toString(),
      'severityNumber': r.level.otelSeverityNumber,
      'severityText': r.level.otelSeverityText,
      'body': {'stringValue': r.message},
      'attributes': _otlpAttributes(attrs),
    };
  }

  /// Encode une map plate dans la forme `KeyValue[]` d'OTLP attendue par
  /// Signoz. Les types inconnus sont convertis via `toString()` plutôt que
  /// jetés, pour que l'appelant voie toujours *quelque chose* dans Signoz.
  List<Map<String, dynamic>> _otlpAttributes(Map<String, Object?> map) {
    final out = <Map<String, dynamic>>[];
    for (final e in map.entries) {
      final value = e.value;
      Map<String, dynamic> wrapped;
      if (value == null) {
        // OTLP n'a pas de null explicite — encode en chaîne vide pour que la
        // clé reste indexée.
        wrapped = {'stringValue': ''};
      } else if (value is String) {
        wrapped = {'stringValue': value};
      } else if (value is bool) {
        wrapped = {'boolValue': value};
      } else if (value is int) {
        wrapped = {'intValue': value.toString()};
      } else if (value is double) {
        wrapped = {'doubleValue': value};
      } else {
        wrapped = {'stringValue': value.toString()};
      }
      out.add({'key': e.key, 'value': wrapped});
    }
    return out;
  }

  int _nowUnixNano() => DateTime.now().microsecondsSinceEpoch * 1000;

  /// Stoppe le flush périodique et expédie ce qui reste en tampon. Tests /
  /// chemins de hot-reload uniquement.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await flush();
    _dio.close(force: true);
  }
}

class _PendingRecord {
  final int timestampNanos;
  final LogLevel level;
  final String message;
  final Map<String, Object?> attributes;
  final Object? error;
  final StackTrace? stack;

  _PendingRecord({
    required this.timestampNanos,
    required this.level,
    required this.message,
    required this.attributes,
    this.error,
    this.stack,
  });
}
