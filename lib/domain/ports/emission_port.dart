import '../value_objects/emission_level.dart';
import '../value_objects/recording.dart';

/// Émission vocale push-to-talk. Le jumeau InMemory simule ; l'adapter natif
/// branche le micro réel (cf. ARCHITECTURE §9).
abstract interface class EmissionPort {
  /// Ouvre le micro (permission au 1ᵉʳ usage).
  Future<void> start();

  /// Flux d'amplitude → VU-mètre (aléatoire dans le jumeau, réel en natif).
  Stream<EmissionLevel> levels();

  /// Clôt la capture et renvoie l'enregistrement à diffuser, ou `null` si rien
  /// n'a été capté (jumeau de démo / permission refusée). La diffusion (upload)
  /// est confiée à [OutboxPort].
  Future<Recording?> stop();
}
