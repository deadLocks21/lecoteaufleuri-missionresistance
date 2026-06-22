import '../entities/team.dart';
import '../value_objects/partie.dart';

/// Lecture de l'état de **partie** d'une équipe (`GET /sessions/:team/partie`).
/// Sondé périodiquement par l'app : détecte le **début** d'une partie (passage
/// de « en attente » à « en jeu ») et sa **fin** (la partie disparaît). `null` =
/// aucune partie active pour le groupe de l'équipe.
abstract interface class PartiePort {
  Future<Partie?> current(Team team);
}
