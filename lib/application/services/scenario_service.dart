import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mission.dart';
import '../../domain/entities/scenario.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/progress_store.dart';
import '../../domain/ports/scenario_port.dart';
import '../../domain/value_objects/mission_progress.dart';
import '../../infrastructure/di.dart';
import '../../infrastructure/http/api_config.dart';
import '../../infrastructure/memory/in_memory_progress_store.dart';
import '../../infrastructure/memory/in_memory_scenario.dart';
import '../../infrastructure/scenario/cached_scenario.dart';
import '../../infrastructure/scenario/disk_progress_store.dart';
import '../../infrastructure/scenario/http_scenario.dart';
import '../session/session_controller.dart';

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
    // Équipe authentifiée (récupération « en fonction de l'équipe ») ; repli sur
    // l'équipe de démo tant qu'on n'est pas déverrouillé.
    final Team team =
        ref.watch(currentTeamProvider) ?? ref.watch(demoTeamProvider);

    final scenario = await port.load(team);
    final stored = await store.read();
    return ScenarioSnapshot(
      scenario: scenario,
      progress: _initialOrReconciled(scenario, stored),
    );
  }

  /// Progression de départ (rien de persisté) ou progression persistée
  /// **réconciliée** avec le scénario courant (qui a pu être ré-édité en régie :
  /// moins de missions / moins d'indices). Évite tout index hors borne.
  static MissionProgress _initialOrReconciled(
    Scenario scenario,
    MissionProgress? stored,
  ) {
    final length = scenario.length;

    if (stored == null) {
      // Sans backend : état « vitrine » de la démo. Avec backend : départ neuf
      // dimensionné au scénario (mission 0, aucun indice déchiffré).
      if (kApiBaseUrl.isEmpty) return MissionProgress.demo();
      return MissionProgress(
        currentMission: 0,
        unlocked: List<int>.filled(length, 0),
        flipped: const <String>{},
      );
    }

    final unlocked = List<int>.filled(length, 0);
    for (var i = 0; i < length && i < stored.unlocked.length; i++) {
      unlocked[i] = stored.unlocked[i].clamp(0, scenario.missions[i].clueCount).toInt();
    }
    return MissionProgress(
      currentMission:
          length == 0 ? 0 : stored.currentMission.clamp(0, length - 1).toInt(),
      unlocked: unlocked,
      flipped: stored.flipped,
    );
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

/// Scénario de l'équipe. Backend configuré ([kApiBaseUrl] non vide) → adapter
/// réseau **offline-first** ([CachedScenario] sur [HttpScenario] : réseau →
/// cache local → démo) ; sinon jumeau de démo. `load(team)` reçoit l'équipe.
final scenarioPortProvider = Provider<ScenarioPort>((ref) {
  if (kApiBaseUrl.isEmpty) return InMemoryScenario();
  return CachedScenario(HttpScenario(baseUrl: kApiBaseUrl));
});

/// Progression : backend + équipe connue → [DiskProgressStore] (prefs locales +
/// push réseau bufferisé, clé = `team.id`) ; sinon jumeau en mémoire. Rebascule
/// au déverrouillage (dépend de [currentTeamProvider]).
final progressStoreProvider = Provider<ProgressStore>((ref) {
  final team = ref.watch(currentTeamProvider);
  if (kApiBaseUrl.isEmpty || team == null) return InMemoryProgressStore();
  return DiskProgressStore(teamId: team.id, baseUrl: kApiBaseUrl);
});

final scenarioServiceProvider =
    AsyncNotifierProvider<ScenarioService, ScenarioSnapshot>(
  ScenarioService.new,
);
