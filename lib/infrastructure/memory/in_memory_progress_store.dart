import '../../domain/ports/progress_store.dart';
import '../../domain/value_objects/mission_progress.dart';

/// Jumeau InMemory de [ProgressStore] : garde la progression en mémoire vive.
/// Le poste reverrouille / repart de zéro à chaque lancement, comme le
/// prototype (la persistance disque est optionnelle, BRIEF §2 / §13.4).
class InMemoryProgressStore implements ProgressStore {
  MissionProgress? _saved;

  @override
  Future<MissionProgress?> read() async => _saved;

  @override
  Future<void> write(MissionProgress progress) async {
    _saved = progress;
  }
}
