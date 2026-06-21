import 'package:dio/dio.dart';

import '../../domain/entities/scenario.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/scenario_port.dart';
import 'scenario_json.dart';

/// Adapter réseau de [ScenarioPort] : récupère le scénario d'une équipe via
/// `GET /sessions/<teamId>/scenario`.
///
/// Laisse **remonter** toute erreur (réseau, réponse invalide) : c'est le
/// décorateur [CachedScenario] qui décide du repli (cache local puis démo).
class HttpScenario implements ScenarioPort {
  HttpScenario({required String baseUrl, Dio? dio})
      : _dio = dio ??
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

  @override
  Future<Scenario> load(Team team) async {
    final resp =
        await _dio.get<Map<String, dynamic>>('/sessions/${team.id}/scenario');
    final scenario = resp.data?['scenario'];
    if (scenario is! Map<String, dynamic>) {
      throw const FormatException('réponse scénario invalide');
    }
    return scenarioFromJson(scenario);
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
