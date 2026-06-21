import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/session_store.dart';
import '../../domain/value_objects/stored_session.dart';

/// Implémentation réelle de [SessionStore] sur `shared_preferences` : une seule
/// clé JSON (`session`) contenant le code + l'identité d'équipe.
class SharedPrefsSessionStore implements SessionStore {
  static const String _key = 'session';

  @override
  Future<StoredSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final code = map['code'];
      final teamId = map['teamId'];
      final teamName = map['teamName'];
      if (code is! String || teamId is! String || teamName is! String) {
        return null;
      }
      return StoredSession(code: code, teamId: teamId, teamName: teamName);
    } catch (_) {
      // Donnée corrompue : on repart d'un écran de code propre.
      return null;
    }
  }

  @override
  Future<void> save(StoredSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'code': session.code,
        'teamId': session.teamId,
        'teamName': session.teamName,
      }),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
