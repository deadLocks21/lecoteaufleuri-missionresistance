import '../value_objects/mission_progress.dart';

/// Persistance de la progression du scénario (locale d'abord, BRIEF §13.4).
/// Le jumeau InMemory garde la valeur en mémoire (reverrouille à chaque
/// lancement, comme le prototype).
abstract interface class ProgressStore {
  Future<MissionProgress?> read();
  Future<void> write(MissionProgress progress);
}
