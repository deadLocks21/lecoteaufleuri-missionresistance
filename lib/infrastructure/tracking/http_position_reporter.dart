import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../domain/ports/position_reporter_port.dart';
import '../../domain/value_objects/gps_position.dart';

/// Adapter réseau de [PositionReporterPort] : poste les positions par lots sur
/// `<baseUrl>/sessions/<teamId>/positions`.
///
/// Calqué sur `SignozLogger` (tampon en mémoire + flush périodique + flush
/// explicite), avec **une différence clé** : un lot qui échoue est **remis en
/// tête de file** pour être réessayé. C'est le buffer hors-ligne — sur un
/// terrain sans réseau, les points s'accumulent et partent au retour du signal
/// (on veut revoir la trace *plus tard*, pas du temps réel strict).
///
/// La file est plafonnée à [maxQueueSize] ; en cas de coupure prolongée, les
/// points **les plus anciens** sont évincés en premier.
class HttpPositionReporter implements PositionReporterPort {
  HttpPositionReporter({
    required String baseUrl,
    required this.teamId,
    Dio? dio,
    this.flushInterval = const Duration(seconds: 20),
    this.maxBatchSize = 100,
    this.maxQueueSize = 2000,
  })  : _endpoint = '${_trimTrailingSlash(baseUrl)}/sessions/$teamId/positions',
        _heartbeatEndpoint =
            '${_trimTrailingSlash(baseUrl)}/sessions/$teamId/heartbeat',
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                contentType: 'application/json',
                responseType: ResponseType.plain,
              ),
            ) {
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  final String teamId;
  final String _endpoint;
  final String _heartbeatEndpoint;
  final Dio _dio;
  final Duration flushInterval;
  final int maxBatchSize;
  final int maxQueueSize;

  final List<GpsPosition> _buffer = [];
  Timer? _timer;
  bool _disposed = false;
  Future<void>? _inflight;

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  @override
  Future<void> report(GpsPosition position) async {
    if (_disposed) return;
    _buffer.add(position);
    _enforceCap();
    if (_buffer.length >= maxBatchSize) {
      unawaited(flush());
    }
  }

  @override
  Future<void> heartbeat() async {
    if (_disposed) return;
    try {
      await _dio.post<dynamic>(_heartbeatEndpoint);
    } catch (e) {
      // Best-effort : un battement raté se rattrape au suivant, inutile de
      // requeue (contrairement aux points de position).
      developer.log(
        'tracking: battement de cœur non délivré (réseau)',
        name: 'mission_resistance.tracking',
        level: 800,
        error: e,
      );
    }
  }

  @override
  Future<void> flush() async {
    // Une seule expédition à la fois (coalesce les flushes concurrents).
    if (_inflight != null) return _inflight;
    if (_buffer.isEmpty) return;
    // Envoie les plus anciens d'abord, par paquets bornés.
    final batch = _buffer.take(maxBatchSize).toList(growable: false);
    _buffer.removeRange(0, batch.length);
    final future = _ship(batch);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _ship(List<GpsPosition> batch) async {
    try {
      await _dio.post<dynamic>(
        _endpoint,
        data: jsonEncode({
          'positions': batch.map((p) => p.toJson()).toList(growable: false),
        }),
      );
    } catch (e, st) {
      // Échec réseau : on remet le lot en tête pour réessayer au prochain
      // flush (buffer hors-ligne). Le plafond peut ensuite évincer les plus
      // vieux si la coupure dure.
      _buffer.insertAll(0, batch);
      _enforceCap();
      developer.log(
        'tracking: échec d\'envoi de ${batch.length} position(s) — réessai différé',
        name: 'mission_resistance.tracking',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Plafonne la file en évinçant les points les plus anciens (en tête).
  void _enforceCap() {
    final overflow = _buffer.length - maxQueueSize;
    if (overflow > 0) {
      _buffer.removeRange(0, overflow);
    }
  }

  /// Stoppe le flush périodique et expédie ce qui reste. Cycle de vie / tests.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await flush();
    _dio.close(force: true);
  }
}
