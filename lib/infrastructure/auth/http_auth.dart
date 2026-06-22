import 'package:dio/dio.dart';

import '../../domain/entities/team.dart';
import '../../domain/exceptions/domain_exception.dart';
import '../../domain/ports/auth_port.dart';
import '../../domain/value_objects/access_code.dart';
import '../../domain/value_objects/partie.dart';

/// Adapter réseau de [AuthPort] : résout un code en équipe via le backend
/// (`POST /auth/login`). `401` → [InvalidCodeException] (shake « code
/// incorrect ») ; tout autre échec (réseau, serveur) → [NetworkException]
/// (indice distinct côté UI).
///
/// Le `channel` (fréquence du bandeau) est **décoratif** et identique pour
/// toutes les équipes : le groupe de communication ne porte pas de fréquence
/// (décision produit).
class HttpAuth implements AuthPort {
  HttpAuth({required String baseUrl, required String channel, Dio? dio})
      : _channel = channel,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                contentType: 'application/json',
              ),
            );

  final Dio _dio;
  final String _channel;

  @override
  Future<LoginResult> unlock(AccessCode code) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'code': code.value},
      );
      final team = resp.data?['team'];
      if (team is! Map) {
        throw const NetworkException();
      }
      final id = team['id'];
      final name = team['name'];
      if (id is! String || name is! String) {
        throw const NetworkException();
      }
      return LoginResult(
        team: Team(id: id, name: name, channel: _channel),
        partie: _partie(resp.data?['partie']),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const InvalidCodeException();
      }
      throw const NetworkException();
    }
  }

  /// Partie active renvoyée au login (`{id,label}`), ou `null` si aucune.
  Partie? _partie(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String) return null;
    return Partie(id: id, label: raw['label'] as String?);
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
