import '../entities/radio_message.dart';
import '../value_objects/emission_level.dart';

/// Émission vocale push-to-talk. Le jumeau InMemory simule ; l'adapter natif
/// branchera le micro réel (cf. ARCHITECTURE §9).
abstract interface class EmissionPort {
  /// Ouvre le micro (permission au 1ᵉʳ usage).
  Future<void> start();

  /// Flux d'amplitude → VU-mètre (aléatoire dans le jumeau, réel en natif).
  Stream<EmissionLevel> levels();

  /// Clôt, (upload +) diffuse, et renvoie le message émis.
  Future<RadioMessage> stop();
}
