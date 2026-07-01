import 'dart:async';
import 'dart:io';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/outbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import '../../domain/value_objects/message_recipient.dart';
import '../../domain/value_objects/message_target.dart';
import '../../domain/value_objects/recording.dart';

/// Jumeau InMemory de [OutboxPort] : « diffuse » sans réseau. Renvoie un message
/// écho marqué `mine` (affiché « ÉMIS » dans la réception, comme en backend) et
/// nettoie le fichier capté par le micro réel (utilisé même en démo pour le VU).
class InMemoryOutbox implements OutboxPort {
  @override
  Future<RadioMessage> send(Recording recording, {MessageTarget? target}) async {
    final file = File(recording.path);
    unawaited(file.delete().catchError((_) => file));
    final now = DateTime.now();
    return RadioMessage(
      id: MessageId('tx-${now.microsecondsSinceEpoch}'),
      sender: 'CE POSTE',
      sentAt: now,
      duration: recording.duration,
      subtitle: 'Votre transmission',
      status: MessageStatus.heard,
      mine: true,
      recipient: switch (target) {
        TeamTarget(:final name) =>
          MessageRecipient(kind: RecipientKind.team, name: name),
        AllTarget() => const MessageRecipient(kind: RecipientKind.all),
        null => null,
      },
    );
  }
}
