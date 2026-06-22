import 'package:shared_preferences/shared_preferences.dart';

/// Persiste localement, par équipe, l'ensemble des ids de messages radio **déjà
/// écoutés**, dans `shared_preferences`.
///
/// Le statut « lu » est une vérité purement **locale** (un poste = un appareil,
/// cf. [HttpInbox.markHeard]) ; on la rend **durable** pour qu'un message déjà
/// écouté ne réapparaisse pas « NOUVEAU » après un redémarrage de l'app (l'état
/// mémoire des providers, lui, repart à zéro).
class HeardStore {
  HeardStore(this.teamId) : _key = '$keyPrefix$teamId';

  final String teamId;
  final String _key;

  /// Préfixe des clés `shared_preferences` (une entrée par équipe).
  static const String keyPrefix = 'radio_heard:';

  /// Cache mémoire pour éviter une lecture disque à chaque `fetch`/sondage.
  Set<String>? _cache;

  /// Ids des messages déjà écoutés pour cette équipe.
  Future<Set<String>> ids() async {
    if (_cache case final cached?) return cached;
    final prefs = await SharedPreferences.getInstance();
    return _cache = prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  /// Marque [id] comme écouté (idempotent) et persiste.
  Future<void> add(String id) async {
    final current = await ids();
    if (!current.add(id)) return; // déjà connu → pas de réécriture disque
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current.toList());
  }

  /// Efface les « lus » mémorisés de **toutes** les équipes (réinit du poste).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(keyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
