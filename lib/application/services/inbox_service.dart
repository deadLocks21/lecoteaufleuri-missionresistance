import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/inbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import '../../infrastructure/di.dart';
import '../../infrastructure/http/api_config.dart';
import '../../infrastructure/memory/in_memory_inbox.dart';
import '../../infrastructure/radio/http_inbox.dart';
import '../config/timings.dart';
import '../session/session_controller.dart';

/// Charge et pilote la boîte de réception (BRIEF §8.2 / ARCHITECTURE §10).
/// Statuts : `unread` → `playing` → `heard` (réécoutable à volonté).
class InboxService extends AsyncNotifier<List<RadioMessage>> {
  @override
  Future<List<RadioMessage>> build() async {
    final port = ref.watch(inboxPortProvider);
    // Écoute des nouveaux messages (polling ~8 s en natif ; vide en démo).
    final sub = port.incoming().listen(_prepend);
    ref.onDispose(sub.cancel);
    return port.fetch();
  }

  void _prepend(RadioMessage message) {
    final list = state.asData?.value;
    if (list == null) return;
    state = AsyncData([message, ...list]);
  }

  /// Joue un message : passe en `playing`, lit l'audio (réel si `audioUrl`,
  /// sinon délai simulé en démo), puis `heard` (et persiste le « lu »).
  Future<void> play(MessageId id) async {
    final list = state.asData?.value;
    if (list == null) return;
    final index = list.indexWhere((m) => m.id.value == id.value);
    if (index < 0 || list[index].isPlaying) return;

    final message = list[index];
    _setStatus(id, MessageStatus.playing);
    try {
      final url = message.audioUrl;
      if (url != null) {
        await ref.read(playerPortProvider).play(url);
      } else {
        // Démo : pas de clip distant → lecture simulée (BRIEF §8.2).
        await Future<void>.delayed(Timings.playback(message.duration));
      }
    } catch (_) {
      // Lecture best-effort : on n'enferme pas la tuile en « playing ».
    }
    await ref.read(inboxPortProvider).markHeard(id);
    _setStatus(id, MessageStatus.heard);
  }

  void _setStatus(MessageId id, MessageStatus status) {
    final list = state.asData?.value;
    if (list == null) return;
    state = AsyncData([
      for (final message in list)
        if (message.id.value == id.value)
          message.copyWith(status: status)
        else
          message,
    ]);
  }
}

final inboxServiceProvider =
    AsyncNotifierProvider<InboxService, List<RadioMessage>>(InboxService.new);

/// Boîte de réception : backend configuré ([kApiBaseUrl] non vide) → adapter
/// réseau ([HttpInbox], scopé à l'équipe courante, polling ~8 s) ; sinon jumeau
/// de démo (3 messages, sans push). Rebascule au déverrouillage (dépend de
/// [currentTeamProvider]).
final inboxPortProvider = Provider<InboxPort>((ref) {
  if (kApiBaseUrl.isEmpty) return InMemoryInbox();
  final Team team =
      ref.watch(currentTeamProvider) ?? ref.watch(demoTeamProvider);
  return HttpInbox(baseUrl: kApiBaseUrl, teamId: team.id);
});
