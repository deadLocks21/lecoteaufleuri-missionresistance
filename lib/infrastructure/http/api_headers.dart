import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identifiant **stable par appareil**, généré au premier lancement et persisté
/// localement (SharedPreferences). Envoyé dans l'en-tête `X-Device-Id` sur
/// chaque requête réseau, pour que le backend puisse **filtrer / tracer** les
/// requêtes par appareil (téléphones tenus par les adultes, distribution
/// interne — voir GPS tracking).
///
/// Chargé **une seule fois** au démarrage ([ensureLoaded] dans `main`), puis lu
/// de façon synchrone par les adapters HTTP via [value] (les `BaseOptions` se
/// construisent sans `await`).
class DeviceId {
  DeviceId._();

  static const _key = 'device_id';
  static String? _value;

  /// Identifiant courant, ou `null` tant que [ensureLoaded] n'a pas résolu
  /// (les adapters n'ajoutent alors pas l'en-tête).
  static String? get value => _value;

  /// Charge l'identifiant persisté, en générant puis sauvegardant un UUID au
  /// premier lancement. Idempotent (retourne le cache si déjà chargé).
  static Future<String> ensureLoaded() async {
    final cached = _value;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    return _value = id;
  }
}

/// En-têtes communs à toutes les requêtes réseau. Fusionne l'identifiant
/// d'appareil ([DeviceId]) et, si présente, la partie courante (`X-Partie-Id`).
/// Retourne `null` quand il n'y a rien à envoyer, pour rester compatible avec le
/// `headers` optionnel des `BaseOptions`.
Map<String, String>? apiHeaders({String? partieId}) {
  final headers = <String, String>{
    'X-Device-Id': ?DeviceId.value,
    'X-Partie-Id': ?partieId,
  };
  return headers.isEmpty ? null : headers;
}
