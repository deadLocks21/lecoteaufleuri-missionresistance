import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/value_objects/message_id.dart';
import '../../infrastructure/di.dart';
import '../config/timings.dart';

/// Charge et pilote la boîte de réception (BRIEF §8.2 / ARCHITECTURE §10).
/// Statuts : `unread` → `playing` → `heard` (réécoutable à volonté).
class InboxService extends AsyncNotifier<List<RadioMessage>> {
  @override
  Future<List<RadioMessage>> build() async {
    final port = ref.watch(inboxPortProvider);
    // Écoute des nouveaux messages (vide en démo ; WebSocket en natif).
    final sub = port.incoming().listen(_prepend);
    ref.onDispose(sub.cancel);
    return port.fetch();
  }

  void _prepend(RadioMessage message) {
    final list = state.asData?.value;
    if (list == null) return;
    state = AsyncData([message, ...list]);
  }

  /// Joue un message : passe en `playing`, attend la durée simulée, puis `heard`
  /// (et persiste le « lu »). En natif, remplacer le délai par la lecture audio.
  Future<void> play(MessageId id) async {
    final list = state.asData?.value;
    if (list == null) return;
    final index = list.indexWhere((m) => m.id.value == id.value);
    if (index < 0 || list[index].isPlaying) return;

    final message = list[index];
    _setStatus(id, MessageStatus.playing);
    await Future<void>.delayed(Timings.playback(message.duration));
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
