import 'package:dio/dio.dart';

import '../http/api_headers.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/partie_port.dart';
import '../../domain/value_objects/partie.dart';

/// Adapter réseau de [PartiePort] : `GET /sessions/<teamId>/partie`. Laisse
/// **remonter** les erreurs réseau : le contrôleur les attrape et **garde son
/// état** (pas de bascule « terminée » sur un simple aléa réseau ; seul un `null`
/// franc — partie absente côté serveur — termine la partie). `null` = aucune
/// partie active pour le groupe.
class HttpPartie implements PartiePort {
  HttpPartie({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                contentType: 'application/json',
                headers: apiHeaders(),
              ),
            );

  final Dio _dio;

  @override
  Future<Partie?> current(Team team) async {
    final resp =
        await _dio.get<Map<String, dynamic>>('/sessions/${team.id}/partie');
    final p = resp.data?['partie'];
    if (p is! Map<String, dynamic>) return null;
    final id = p['id'];
    if (id is! String) return null;
    return Partie(id: id, label: p['label'] as String?);
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
