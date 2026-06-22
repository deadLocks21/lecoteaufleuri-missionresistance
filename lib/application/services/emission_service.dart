import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/team.dart';
import '../../domain/ports/outbox_port.dart';
import '../../domain/value_objects/emission_level.dart';
import '../../domain/value_objects/recording.dart';
import '../../infrastructure/di.dart';
import '../../infrastructure/http/api_config.dart';
import '../../infrastructure/memory/in_memory_outbox.dart';
import '../../infrastructure/radio/http_outbox.dart';
import '../config/timings.dart';
import '../session/partie_controller.dart';
import '../session/session_controller.dart';
import 'inbox_service.dart';

/// Phase du push-to-talk.
enum EmissionPhase { idle, live, sent }

/// État présenté de l'émission (BRIEF §8.1.b).
class EmissionState {
  const EmissionState({
    required this.phase,
    required this.seconds,
    required this.level,
  });

  final EmissionPhase phase;

  /// Chrono pendant `live` ; durée envoyée pendant `sent`.
  final int seconds;

  /// Niveau courant du VU-mètre (repos quand inactif).
  final EmissionLevel level;

  static const idle = EmissionState(
    phase: EmissionPhase.idle,
    seconds: 0,
    level: EmissionLevel.rest,
  );

  bool get isLive => phase == EmissionPhase.live;
  bool get isSent => phase == EmissionPhase.sent;

  EmissionState copyWith({
    EmissionPhase? phase,
    int? seconds,
    EmissionLevel? level,
  }) {
    return EmissionState(
      phase: phase ?? this.phase,
      seconds: seconds ?? this.seconds,
      level: level ?? this.level,
    );
  }
}

/// Pilote l'émission vocale (start/level/stop + chrono) via [EmissionPort], puis
/// **diffuse** l'enregistrement via [OutboxPort]. La capture (micro) et l'envoi
/// (réseau) sont deux ports distincts : le VU-mètre tourne même sans backend.
class EmissionService extends Notifier<EmissionState> {
  Timer? _chrono;
  StreamSubscription<EmissionLevel>? _levelsSub;
  Timer? _resetTimer;

  @override
  EmissionState build() {
    ref.onDispose(_cleanup);
    return EmissionState.idle;
  }

  /// Appui maintenu : ouvre le micro, lance le VU et le chrono.
  Future<void> startTx() async {
    if (state.isLive) return;
    _resetTimer?.cancel();
    final port = ref.read(emissionPortProvider);
    await port.start();
    state = const EmissionState(
      phase: EmissionPhase.live,
      seconds: 0,
      level: EmissionLevel.rest,
    );
    _levelsSub = port.levels().listen((level) {
      if (state.isLive) state = state.copyWith(level: level);
    });
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isLive) state = state.copyWith(seconds: state.seconds + 1);
    });
  }

  /// Relâché : clôt la capture, diffuse en arrière-plan, renvoie la durée (s)
  /// pour le libellé « (Xs) ».
  Future<int> stopTx() async {
    if (!state.isLive) return state.seconds;
    final seconds = state.seconds;
    _chrono?.cancel();
    _chrono = null;
    await _levelsSub?.cancel();
    _levelsSub = null;

    final recording = await ref.read(emissionPortProvider).stop();
    state = EmissionState(
      phase: EmissionPhase.sent,
      seconds: seconds,
      level: EmissionLevel.rest,
    );
    _resetTimer = Timer(Timings.pttSubReset, () {
      if (state.isSent) state = EmissionState.idle;
    });

    // Diffusion **best-effort** en arrière-plan : l'UI passe en « envoyé » sans
    // attendre le réseau (comme les push GPS/progression, eux aussi best-effort).
    if (recording != null) unawaited(_broadcast(recording));
    return seconds;
  }

  Future<void> _broadcast(Recording recording) async {
    try {
      final message = await ref.read(outboxPortProvider).send(recording);
      // Émission confirmée (persistée) → apparaît tout de suite dans la
      // réception, marquée « ÉMIS ». Échec → rien (pas de fausse confirmation).
      ref.read(inboxServiceProvider.notifier).addSent(message);
    } catch (_) {
      // Un échec d'envoi ne casse pas l'expérience du poste.
    }
  }

  void _cleanup() {
    _chrono?.cancel();
    _resetTimer?.cancel();
    _levelsSub?.cancel();
  }
}

final emissionServiceProvider =
    NotifierProvider<EmissionService, EmissionState>(EmissionService.new);

/// Diffusion d'une émission : backend configuré ([kApiBaseUrl] non vide) → upload
/// réseau ([HttpOutbox], scopé à l'équipe courante) ; sinon jumeau de démo (écho,
/// sans réseau). Rebascule au déverrouillage (dépend de [currentTeamProvider]).
final outboxPortProvider = Provider<OutboxPort>((ref) {
  if (kApiBaseUrl.isEmpty) return InMemoryOutbox();
  final Team team =
      ref.watch(currentTeamProvider) ?? ref.watch(demoTeamProvider);
  return HttpOutbox(
    baseUrl: kApiBaseUrl,
    teamId: team.id,
    partieId: ref.watch(currentPartieIdProvider),
  );
});
