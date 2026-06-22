import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scenario.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/scenario_port.dart';
import '../memory/demo_data.dart';
import 'scenario_json.dart';

/// Décorateur **offline-first** de [ScenarioPort] :
/// 1. tente le réseau ([HttpScenario]) ; succès → écrit le cache local puis le rend ;
/// 2. échec réseau → rend le dernier scénario mis en cache **pour cette équipe** ;
/// 3. aucun cache → repli sur le scénario de démo (jamais d'échec dur).
///
/// Cache = une clé `shared_preferences` par équipe (`scenario_cache:<id>`),
/// même pattern JSON que `SharedPrefsSessionStore` (pas de fuite inter-équipes).
class CachedScenario implements ScenarioPort {
  CachedScenario(this._network);

  final ScenarioPort _network;

  /// Préfixe des clés `shared_preferences` (une entrée par équipe).
  static const String keyPrefix = 'scenario_cache:';

  static String _key(String teamId) => '$keyPrefix$teamId';

  /// Efface le scénario mis en cache de **toutes** les équipes (réinitialisation
  /// du poste).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(keyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  @override
  Future<Scenario> load(Team team) async {
    try {
      final scenario = await _network.load(team);
      await _writeCache(team.id, scenario);
      return scenario;
    } catch (_) {
      final cached = await _readCache(team.id);
      if (cached != null) return cached;
      return DemoData.scenario();
    }
  }

  Future<void> _writeCache(String teamId, Scenario scenario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(teamId), jsonEncode(scenarioToJson(scenario)));
  }

  Future<Scenario?> _readCache(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(teamId));
    if (raw == null) return null;
    try {
      return scenarioFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // donnée corrompue → comme si pas de cache
    }
  }
}
