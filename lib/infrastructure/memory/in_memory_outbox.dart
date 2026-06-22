import 'dart:async';
import 'dart:io';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/outbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import '../../domain/value_objects/recording.dart';

/// Jumeau InMemory de [OutboxPort] : « diffuse » sans réseau. Renvoie un message
/// écho (jamais reçu par d'autres postes en démo) et nettoie le fichier capté
/// par le micro réel (utilisé même en démo pour le VU-mètre).
class InMemoryOutbox implements OutboxPort {
  @override
  Future<RadioMessage> send(Recording recording) async {
    unawaited(File(recording.path).delete().catchError((e) => File(recording.path)));
    final now = DateTime.now();
    return RadioMessage(
      id: MessageId('tx-${now.microsecondsSinceEpoch}'),
      sender: 'CE POSTE',
      sentAt: now,
      duration: recording.duration,
      subtitle: 'Émission locale',
    );
  }
}
