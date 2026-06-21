import '../../domain/ports/session_store.dart';
import '../../domain/value_objects/stored_session.dart';

/// Jumeau InMemory de [SessionStore] (tests / dev sans persistance disque).
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this._session]);

  StoredSession? _session;

  @override
  Future<StoredSession?> load() async => _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
