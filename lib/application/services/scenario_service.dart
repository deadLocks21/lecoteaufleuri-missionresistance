import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mission.dart';
import '../../domain/entities/scenario.dart';
import '../../domain/value_objects/mission_progress.dart';
import '../../infrastructure/di.dart';

/// Scénario + progression à un instant donné.
class ScenarioSnapshot {
  const ScenarioSnapshot({required this.scenario, required this.progress});

  final Scenario scenario;
  final MissionProgress progress;

  Mission get currentMission =>
      scenario.missionAt(progress.currentMission);

  /// Progression en pourcentage : `round(m / total × 100)` (BRIEF §9.1).
  int get percent =>
      (progress.currentMission / scenario.length * 100).round();

  ScenarioSnapshot copyWith({MissionProgress? progress}) => ScenarioSnapshot(
        scenario: scenario,
        progress: progress ?? this.progress,
      );
}

/// Charge le scénario de l'équipe, déverrouille séquentiellement les indices,
/// gère replier/revoir et « Mission accomplie », et persiste la progression
/// (ARCHITECTURE §11).
class ScenarioService extends AsyncNotifier<ScenarioSnapshot> {
  @override
  Future<ScenarioSnapshot> build() async {
    final port = ref.watch(scenarioPortProvider);
    final store = ref.watch(progressStoreProvider);
    final team = ref.watch(demoTeamProvider);

    final scenario = await port.load(team);
    final progress = await store.read() ?? MissionProgress.demo();
    return ScenarioSnapshot(scenario: scenario, progress: progress);
  }

  Future<void> _update(MissionProgress progress) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    await ref.read(progressStoreProvider).write(progress);
    state = AsyncData(snapshot.copyWith(progress: progress));
  }

  /// Déchiffre l'indice disponible de la mission en cours. Renvoie le numéro
  /// (1-based) déchiffré pour le bandeau, ou `null` si plus rien à déchiffrer.
  Future<int?> decipherCurrent() async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return null;
    final unlocked = snapshot.progress.unlockedForCurrent;
    if (unlocked >= snapshot.currentMission.clueCount) return null;
    await _update(snapshot.progress.decipherCurrent());
    return unlocked + 1;
  }

  /// Replie / re-révèle une carte déjà déchiffrée de la mission en cours.
  Future<void> toggleFlip(int clueIndex) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    await _update(
      snapshot.progress.toggleFlip(snapshot.progress.currentMission, clueIndex),
    );
  }

  /// Passe à la mission suivante. Renvoie `false` si le scénario est terminé.
  Future<bool> completeMission() async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return false;
    if (!snapshot.scenario.hasNextAfter(snapshot.progress.currentMission)) {
      return false;
    }
    await _update(snapshot.progress.advanceMission());
    return true;
  }
}

final scenarioServiceProvider =
    AsyncNotifierProvider<ScenarioService, ScenarioSnapshot>(
  ScenarioService.new,
);
