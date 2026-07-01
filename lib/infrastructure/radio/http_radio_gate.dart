import 'package:dio/dio.dart';

import '../http/api_headers.dart';
import '../../domain/ports/radio_gate_port.dart';
import '../../domain/value_objects/radio_gate.dart';
import '../../domain/value_objects/recipient.dart';

/// Adapter réseau de [RadioGatePort] : lit l'état radio (coupe-radio + capacités
/// d'adressage) via `GET /sessions/<teamId>/radio/status`, puis **sonde** (~8 s,
/// cohérent avec la réception) afin de réagir vite quand la régie coupe/rétablit
/// la radio ou que la liste des équipes change. Comme le poll de partie,
/// l'endpoint ne demande pas d'en-tête de partie : le serveur résout l'état
/// courant.
class HttpRadioGate implements RadioGatePort {
  HttpRadioGate({
    required String baseUrl,
    required this.teamId,
    String? partieId,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                contentType: 'application/json',
                headers: apiHeaders(partieId: partieId),
              ),
            );

  final Dio _dio;
  final String teamId;

  static const Duration _pollEvery = Duration(seconds: 8);

  @override
  Future<RadioGate> fetch() => _load();

  @override
  Stream<RadioGate> watch() async* {
    var last = const RadioGate(blocked: false, canSend: true);
    while (true) {
      await Future<void>.delayed(_pollEvery);
      final RadioGate gate;
      try {
        gate = await _load();
      } catch (_) {
        continue; // sondage best-effort : on retentera au prochain tick
      }
      if (gate != last) {
        last = gate;
        yield gate;
      }
    }
  }

  Future<RadioGate> _load() async {
    final resp =
        await _dio.get<Map<String, dynamic>>('/sessions/$teamId/radio/status');
    final raw = resp.data?['radio'];
    if (raw is! Map) return RadioGate.open;
    final emitter = resp.data?['emitter'];
    // Champ absent (vieux serveur) → on n'enferme pas le poste (canSend par
    // défaut) et on n'ouvre pas d'adressage (canAddress false).
    return RadioGate(
      blocked: raw['blocked'] == true,
      canSend: raw['canSend'] != false,
      canAddress: emitter is Map && emitter['canAddress'] == true,
      recipients: emitter is Map ? _recipientsFrom(emitter['recipients']) : const [],
    );
  }

  static List<Recipient> _recipientsFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['id'] is String && item['name'] is String)
          Recipient(id: item['id'] as String, name: item['name'] as String),
    ];
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
