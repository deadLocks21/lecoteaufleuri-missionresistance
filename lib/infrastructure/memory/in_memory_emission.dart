import 'dart:math' as math;

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/emission_port.dart';
import '../../domain/value_objects/emission_level.dart';
import '../../domain/value_objects/message_id.dart';

/// Jumeau InMemory de [EmissionPort] : simule l'émission (BRIEF §2). Le flux de
/// niveaux est **aléatoire** toutes les 110 ms ; rien n'est réellement
/// enregistré ni diffusé. L'adapter natif branchera le micro (amplitude réelle).
class InMemoryEmission implements EmissionPort {
  final math.Random _rng = math.Random();
  DateTime? _startedAt;

  @override
  Future<void> start() async {
    _startedAt = DateTime.now();
  }

  @override
  Stream<EmissionLevel> levels() => Stream<EmissionLevel>.periodic(
        const Duration(milliseconds: 110),
        (_) => EmissionLevel.random(_rng),
      );

  @override
  Future<RadioMessage> stop() async {
    final started = _startedAt ?? DateTime.now();
    final duration = DateTime.now().difference(started);
    _startedAt = null;
    // Message « émis » (diffusé aux autres postes en natif ; ignoré ici).
    return RadioMessage(
      id: MessageId('tx-${started.microsecondsSinceEpoch}'),
      sender: 'CE POSTE',
      sentAt: started,
      duration: duration,
      subtitle: 'Émission locale',
    );
  }
}
