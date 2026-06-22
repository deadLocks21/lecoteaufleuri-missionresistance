import '../entities/radio_message.dart';
import '../value_objects/recording.dart';

/// Diffusion d'une émission vocale : upload de l'enregistrement vers le backend,
/// qui le persiste et le rend visible aux autres postes du **groupe** (cf.
/// ARCHITECTURE §9). Le jumeau InMemory simule (écho sans réseau).
abstract interface class OutboxPort {
  /// Envoie l'enregistrement et renvoie le message émis tel que persisté.
  Future<RadioMessage> send(Recording recording);
}
