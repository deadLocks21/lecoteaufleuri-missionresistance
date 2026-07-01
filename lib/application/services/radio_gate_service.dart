import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/team.dart';
import '../../domain/ports/radio_gate_port.dart';
import '../../domain/value_objects/radio_gate.dart';
import '../../infrastructure/di.dart';
import '../../infrastructure/http/api_config.dart';
import '../../infrastructure/memory/in_memory_radio_gate.dart';
import '../../infrastructure/radio/http_radio_gate.dart';
import '../session/partie_controller.dart';
import '../session/session_controller.dart';

/// Suit l'état du **coupe-radio** pour le poste courant : `blocked` (la régie a
/// coupé la radio de la partie) et `canSend` (ce poste peut encore émettre —
/// toujours vrai pour les `nazis`). Alimente le bandeau d'alerte et le grisage du
/// bouton TRANSMETTRE de la vue radio. Charge l'état au montage puis se met à
/// jour par sondage (~8 s).
class RadioGateService extends AsyncNotifier<RadioGate> {
  @override
  Future<RadioGate> build() async {
    final port = ref.watch(radioGatePortProvider);
    final sub = port.watch().listen((gate) => state = AsyncData(gate));
    ref.onDispose(sub.cancel);
    return port.fetch();
  }
}

final radioGateServiceProvider =
    AsyncNotifierProvider<RadioGateService, RadioGate>(RadioGateService.new);

/// Coupe-radio : backend configuré ([kApiBaseUrl] non vide) → adapter
/// [HttpRadioGate] (scopé à l'équipe et à la partie courantes — il se reconstruit
/// donc à chaque nouvelle partie, qui repart radio ouverte) ; sinon jumeau de
/// démo (radio toujours ouverte). Rebascule au déverrouillage.
final radioGatePortProvider = Provider<RadioGatePort>((ref) {
  if (kApiBaseUrl.isEmpty) return InMemoryRadioGate();
  final Team team =
      ref.watch(currentTeamProvider) ?? ref.watch(demoTeamProvider);
  return HttpRadioGate(
    baseUrl: kApiBaseUrl,
    teamId: team.id,
    partieId: ref.watch(currentPartieIdProvider),
  );
});
