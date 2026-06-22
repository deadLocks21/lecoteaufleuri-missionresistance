import 'package:dio/dio.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/inbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import 'heard_store.dart';
import 'radio_json.dart';

/// Adapter réseau de [InboxPort] : récupère les messages **du groupe** de
/// l'équipe via `GET /sessions/<teamId>/radio`, puis **sonde** périodiquement
/// (~8 s, cohérent avec le suivi régie) pour pousser les nouveaux. Un WebSocket
/// temps réel pourra remplacer le polling plus tard ; il suffit pour le jeu.
///
/// L'isolation par groupe et l'exclusion des propres émissions de l'équipe sont
/// assurées **côté serveur** ; l'app affiche la liste telle quelle (récent →
/// ancien).
class HttpInbox implements InboxPort {
  HttpInbox({required String baseUrl, required this.teamId, Dio? dio})
      : _base = _trimTrailingSlash(baseUrl),
        _heard = HeardStore(teamId),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                contentType: 'application/json',
              ),
            );

  final Dio _dio;
  final String _base;
  final String teamId;

  /// Statut « lu » persisté localement (durable entre deux lancements).
  final HeardStore _heard;

  /// Ids déjà vus (semés par [fetch], enrichis par le polling) → on ne re-pousse
  /// pas un message déjà présent dans la boîte.
  final Set<String> _seen = {};

  static const Duration _pollEvery = Duration(seconds: 8);

  String get _audioBase => '$_base/sessions/$teamId/radio';

  @override
  Future<List<RadioMessage>> fetch() async {
    final messages = await _load();
    for (final m in messages) {
      _seen.add(m.id.value);
    }
    return messages;
  }

  @override
  Stream<RadioMessage> incoming() async* {
    while (true) {
      await Future<void>.delayed(_pollEvery);
      final List<RadioMessage> messages;
      try {
        messages = await _load();
      } catch (_) {
        continue; // sondage best-effort : on retentera au prochain tick
      }
      // Du plus ancien au plus récent → le prepend de l'inbox conserve l'ordre
      // (le plus récent finit en tête).
      for (final m in messages.reversed) {
        if (_seen.add(m.id.value)) yield m;
      }
    }
  }

  @override
  Future<void> markHeard(MessageId id) => _heard.add(id.value);

  Future<List<RadioMessage>> _load() async {
    final resp = await _dio.get<Map<String, dynamic>>('/sessions/$teamId/radio');
    final raw = resp.data?['messages'];
    if (raw is! List) return const [];
    final messages = radioMessagesFromJson(raw, audioBase: _audioBase);
    // Réapplique le « lu » persisté : un message déjà écouté lors d'une session
    // précédente revient `heard` (et non `unread`) après un redémarrage.
    final heard = await _heard.ids();
    if (heard.isEmpty) return messages;
    return [
      for (final m in messages)
        if (m.isUnread && heard.contains(m.id.value))
          m.copyWith(status: MessageStatus.heard)
        else
          m,
    ];
  }

  /// Libère le client HTTP (l'isolate de fond du suivi à l'arrêt du service).
  /// L'éventuel flux [incoming] doit être annulé séparément (annulation de la
  /// souscription, qui rompt sa boucle de sondage).
  void dispose() => _dio.close(force: true);

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
