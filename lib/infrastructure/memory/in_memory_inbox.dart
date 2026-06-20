import '../../domain/entities/radio_message.dart';
import '../../domain/ports/inbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import 'demo_data.dart';

/// Jumeau InMemory de [InboxPort] : sert les 3 messages de démo, triés
/// récent → ancien. Pas de push temps réel en démo.
class InMemoryInbox implements InboxPort {
  final Set<String> _heard = {};

  @override
  Future<List<RadioMessage>> fetch() async {
    final messages = DemoData.messages()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return messages;
  }

  @override
  Stream<RadioMessage> incoming() => const Stream<RadioMessage>.empty();

  @override
  Future<void> markHeard(MessageId id) async {
    _heard.add(id.value);
  }
}
