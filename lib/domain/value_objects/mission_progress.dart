/// Progression sérialisable dans le scénario (BRIEF §5.2).
///
/// - [currentMission] : index 0-based de la mission en cours.
/// - [unlocked] : nombre d'indices déchiffrés pour chaque mission.
/// - [flipped] : indices déchiffrés que l'utilisateur a remis face cachée,
///   identifiés par la clé `"m:k"` (mission:indice).
class MissionProgress {
  const MissionProgress({
    required this.currentMission,
    required this.unlocked,
    required this.flipped,
  });

  /// État initial de démo : mission 1 terminée, mission 2 en cours avec
  /// 0 indice déchiffré (BRIEF §5.2).
  factory MissionProgress.demo() => const MissionProgress(
        currentMission: 1,
        unlocked: [2, 0, 0, 0],
        flipped: {},
      );

  final int currentMission;
  final List<int> unlocked;
  final Set<String> flipped;

  /// Nombre d'indices déchiffrés pour la mission en cours.
  int get unlockedForCurrent => unlocked[currentMission];

  /// Clé de mémorisation « repliée » pour la carte (mission, indice).
  static String flipKey(int mission, int clue) => '$mission:$clue';

  bool isFlipped(int mission, int clue) =>
      flipped.contains(flipKey(mission, clue));

  MissionProgress copyWith({
    int? currentMission,
    List<int>? unlocked,
    Set<String>? flipped,
  }) {
    return MissionProgress(
      currentMission: currentMission ?? this.currentMission,
      unlocked: unlocked ?? this.unlocked,
      flipped: flipped ?? this.flipped,
    );
  }

  /// Déchiffre l'indice disponible de la mission en cours (`unlocked[m]++`).
  MissionProgress decipherCurrent() {
    final next = List<int>.of(unlocked);
    next[currentMission] = next[currentMission] + 1;
    return copyWith(unlocked: next);
  }

  /// Replie / re-révèle la carte (mission, indice) déjà déchiffrée.
  MissionProgress toggleFlip(int mission, int clue) {
    final key = flipKey(mission, clue);
    final next = Set<String>.of(flipped);
    if (!next.remove(key)) next.add(key);
    return copyWith(flipped: next);
  }

  /// Passe à la mission suivante (la nouvelle démarre à 0 indice déchiffré).
  MissionProgress advanceMission() =>
      copyWith(currentMission: currentMission + 1);
}
