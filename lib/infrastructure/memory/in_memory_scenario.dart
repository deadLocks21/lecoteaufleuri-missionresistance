import '../../domain/entities/scenario.dart';
import '../../domain/entities/team.dart';
import '../../domain/ports/scenario_port.dart';
import 'demo_data.dart';

/// Jumeau InMemory de [ScenarioPort] : renvoie le scénario de démo (BRIEF §10),
/// indépendamment de l'équipe (le mapping code → contenu viendra du backend).
class InMemoryScenario implements ScenarioPort {
  @override
  Future<Scenario> load(Team team) async => DemoData.scenario();
}
