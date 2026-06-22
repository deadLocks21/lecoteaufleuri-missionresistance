import '../../domain/entities/team.dart';
import '../../domain/ports/partie_port.dart';
import '../../domain/value_objects/partie.dart';

/// Jumeau InMemory de [PartiePort] : en démo (sans backend), une partie est
/// toujours « en cours » pour que le poste joue immédiatement.
class InMemoryPartie implements PartiePort {
  const InMemoryPartie();

  static const Partie demo = Partie(id: 'demo-partie', label: 'Partie de démo');

  @override
  Future<Partie?> current(Team team) async => demo;
}
