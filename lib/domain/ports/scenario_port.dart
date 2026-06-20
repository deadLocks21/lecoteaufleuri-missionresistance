import '../entities/scenario.dart';
import '../entities/team.dart';

/// Charge le scénario d'une équipe (config/backend en natif ; en dur en démo).
abstract interface class ScenarioPort {
  Future<Scenario> load(Team team);
}
