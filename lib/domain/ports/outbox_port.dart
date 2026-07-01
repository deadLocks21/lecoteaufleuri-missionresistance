import '../entities/radio_message.dart';
import '../value_objects/message_target.dart';
import '../value_objects/recording.dart';

/// Diffusion d'une émission vocale : upload de l'enregistrement vers le backend,
/// qui le persiste et l'**adresse** selon le rôle de l'émetteur (cf.
/// ARCHITECTURE §9). Le jumeau InMemory simule (écho sans réseau).
abstract interface class OutboxPort {
  /// Envoie l'enregistrement et renvoie le message émis tel que persisté.
  ///
  /// [target] = destinataire choisi par un poste central / nazi (tout le monde
  /// ou une équipe précise). `null` pour un poste portable : le serveur impose
  /// « vers les postes centraux ».
  Future<RadioMessage> send(Recording recording, {MessageTarget? target});
}
