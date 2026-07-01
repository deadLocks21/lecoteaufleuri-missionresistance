import '../value_objects/radio_gate.dart';

/// Lecture de l'état du **coupe-radio** d'un poste (la régie peut couper la radio
/// d'une partie — cf. feature radio). Le jumeau InMemory considère la radio
/// toujours ouverte (pas de régie en mode démo).
abstract interface class RadioGatePort {
  /// État courant (chargement initial).
  Future<RadioGate> fetch();

  /// Mises à jour périodiques (~8 s, cohérent avec la réception) ; flux vide en
  /// démo. Permet de réagir vite quand la régie coupe ou rétablit la radio.
  Stream<RadioGate> watch();
}
