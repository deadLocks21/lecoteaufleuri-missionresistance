import 'dart:math' as math;

import '../../domain/ports/emission_port.dart';
import '../../domain/value_objects/emission_level.dart';
import '../../domain/value_objects/recording.dart';

/// Jumeau InMemory de [EmissionPort] : simule l'émission (BRIEF §2). Le flux de
/// niveaux est **aléatoire** toutes les 110 ms ; rien n'est réellement
/// enregistré, donc `stop()` renvoie `null` (aucun enregistrement à diffuser).
/// L'adapter natif branche le micro (amplitude réelle + capture fichier).
class InMemoryEmission implements EmissionPort {
  final math.Random _rng = math.Random();

  @override
  Future<void> start() async {}

  @override
  Stream<EmissionLevel> levels() => Stream<EmissionLevel>.periodic(
        const Duration(milliseconds: 110),
        (_) => EmissionLevel.random(_rng),
      );

  @override
  Future<Recording?> stop() async => null;
}
