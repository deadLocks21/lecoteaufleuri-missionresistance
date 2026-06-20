import '../entities/radio_message.dart';
import '../value_objects/message_id.dart';

/// Boîte de réception des messages radio (cf. ARCHITECTURE §10).
abstract interface class InboxPort {
  /// Chargement initial (tri récent → ancien).
  Future<List<RadioMessage>> fetch();

  /// Push temps réel des nouveaux messages (WebSocket en natif ; vide en démo).
  Stream<RadioMessage> incoming();

  /// Persiste le statut « lu » d'un message.
  Future<void> markHeard(MessageId id);
}
