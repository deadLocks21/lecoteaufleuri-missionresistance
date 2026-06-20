import 'mission.dart';

/// Scénario complet d'une équipe : suite ordonnée de missions (BRIEF §10).
class Scenario {
  const Scenario({required this.missions});

  final List<Mission> missions;

  int get length => missions.length;

  Mission missionAt(int index) => missions[index];

  /// `true` s'il existe une mission après [index].
  bool hasNextAfter(int index) => index < missions.length - 1;
}
