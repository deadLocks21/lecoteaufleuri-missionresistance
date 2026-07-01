import '../../domain/ports/radio_gate_port.dart';
import '../../domain/value_objects/radio_gate.dart';

/// Jumeau de démo de [RadioGatePort] : la radio est **toujours ouverte** (pas de
/// régie en mode démo, donc jamais de coupure).
class InMemoryRadioGate implements RadioGatePort {
  @override
  Future<RadioGate> fetch() async => RadioGate.open;

  @override
  Stream<RadioGate> watch() => const Stream<RadioGate>.empty();
}
