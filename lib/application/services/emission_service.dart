import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/emission_level.dart';
import '../../infrastructure/di.dart';
import '../config/timings.dart';

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

/// Pilote l'émission vocale (start/level/stop + chrono) via [EmissionPort].
/// Le jumeau de démo fournit des niveaux aléatoires ; rien n'est enregistré.
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

  /// Relâché : clôt + diffuse, renvoie la durée (s) pour le libellé « (Xs) ».
  Future<int> stopTx() async {
    if (!state.isLive) return state.seconds;
    final seconds = state.seconds;
    _chrono?.cancel();
    _chrono = null;
    await _levelsSub?.cancel();
    _levelsSub = null;
    await ref.read(emissionPortProvider).stop();
    state = EmissionState(
      phase: EmissionPhase.sent,
      seconds: seconds,
      level: EmissionLevel.rest,
    );
    _resetTimer = Timer(Timings.pttSubReset, () {
      if (state.isSent) state = EmissionState.idle;
    });
    return seconds;
  }

  void _cleanup() {
    _chrono?.cancel();
    _resetTimer?.cancel();
    _levelsSub?.cancel();
  }
}

final emissionServiceProvider =
    NotifierProvider<EmissionService, EmissionState>(EmissionService.new);
