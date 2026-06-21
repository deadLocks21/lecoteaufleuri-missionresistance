import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/gps_position.dart';
import '../../infrastructure/telemetry/telemetry_providers.dart';
import '../../infrastructure/tracking/tracking_providers.dart';
import '../session/session_controller.dart';

/// Au-delà de ce délai sans nouveau point alors que le suivi est censé tourner,
/// on considère le service plateforme mort (relance au retour au premier plan).
const Duration _staleAfter = Duration(minutes: 2);

/// Garde-fou « ceinture + bretelles » : même sans date limite configurée, le
/// suivi s'arrête tout seul après cette durée (évite un poste qui émet 3 jours).
const Duration _safetyMaxDuration = Duration(hours: 4);

/// Rythme du « battement de cœur » : tant que l'équipe est à l'arrêt (aucun
/// point distance-filtré), on signale quand même sa présence pour qu'elle ne
/// passe pas « muette » sur la carte. À garder **sous** le seuil de fraîcheur
/// serveur (`POSITION_STALE_AFTER_SECONDS`, 120 s par défaut).
const Duration _heartbeatInterval = Duration(seconds: 45);

enum TrackingStatus { idle, active, stopped, denied, expired }

enum TrackingStopReason { manual, scenarioComplete, deadline }

/// État observable du suivi de position (pour l'UI / le debug).
class TrackingState {
  const TrackingState({
    required this.status,
    this.stopReason,
    this.fixCount = 0,
    this.lastFixAt,
    this.startedAt,
  });

  final TrackingStatus status;
  final TrackingStopReason? stopReason;
  final int fixCount;
  final DateTime? lastFixAt;
  final DateTime? startedAt;

  TrackingState copyWith({
    TrackingStatus? status,
    TrackingStopReason? stopReason,
    int? fixCount,
    DateTime? lastFixAt,
    DateTime? startedAt,
  }) =>
      TrackingState(
        status: status ?? this.status,
        stopReason: stopReason ?? this.stopReason,
        fixCount: fixCount ?? this.fixCount,
        lastFixAt: lastFixAt ?? this.lastFixAt,
        startedAt: startedAt ?? this.startedAt,
      );
}

/// Orchestration du suivi GPS (cf. discussion de faisabilité) :
///
/// - **Démarrage** : au déverrouillage du poste (= début de jeu).
/// - **Lecture** : abonne le capteur ([LocationTrackingPort]) et pousse chaque
///   point vers le backend via [PositionReporterPort] (file hors-ligne + retry).
/// - **Arrêts** (deux sécurités) : *scénario terminé* (appelé depuis le carnet)
///   et *date limite* / durée max ([_safetyMaxDuration]).
/// - **Liveness** : [ensureAlive] (appelé au retour au premier plan) relance le
///   service plateforme si un OEM l'a tué ou si plus aucun point n'arrive.
class TrackingService extends Notifier<TrackingState> {
  StreamSubscription<GpsPosition>? _sub;
  Timer? _deadlineTimer;
  Timer? _heartbeatTimer;

  /// Instant du dernier signal envoyé (point organique **ou** battement) —
  /// évite de battre alors qu'un point vient de partir.
  DateTime? _lastReportAt;

  /// Vrai dès le premier point GPS réel (on ne bat pas avant d'avoir une fix).
  bool _hasFix = false;

  @override
  TrackingState build() {
    ref.onDispose(_teardown);

    // Le suivi suit le cycle de la session : déverrouillage = début de jeu,
    // reverrouillage = arrêt.
    ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
      if (next is Unlocked) {
        unawaited(start());
      } else if (next is Locked && prev is Unlocked) {
        // Reverrouillage depuis l'app (pas le shake d'un mauvais code).
        unawaited(stop(TrackingStopReason.manual));
      }
    });

    // Session déjà déverrouillée quand le service est instancié.
    if (ref.read(sessionControllerProvider) is Unlocked) {
      Future.microtask(start);
    }

    return const TrackingState(status: TrackingStatus.idle);
  }

  Future<void> start() async {
    if (state.status == TrackingStatus.active) return;

    final deadline = ref.read(trackingDeadlineProvider);
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _log('tracking.skipped_expired');
      state = const TrackingState(status: TrackingStatus.expired);
      return;
    }

    bool granted;
    try {
      granted = await ref.read(locationTrackingPortProvider).ensurePermission();
    } catch (e, st) {
      // Plateforme indisponible (canal absent en test, device exotique…) : on
      // dégrade proprement plutôt que de laisser fuir l'exception.
      _log('tracking.permission_error', error: e, stack: st);
      state = const TrackingState(status: TrackingStatus.denied);
      return;
    }
    if (!granted) {
      _log('tracking.permission_denied');
      state = const TrackingState(status: TrackingStatus.denied);
      return;
    }

    _hasFix = false;
    _lastReportAt = null;
    if (!await _subscribe()) {
      state = const TrackingState(status: TrackingStatus.denied);
      return;
    }
    _scheduleStopDeadline(deadline);
    _startHeartbeat();
    state = TrackingState(
      status: TrackingStatus.active,
      startedAt: DateTime.now(),
    );
    _log('tracking.started');
  }

  /// Liveness — appelé au retour au premier plan. Relance si le service est
  /// tombé (OEM) ou si plus aucun point n'arrive (filet anti-coupure de fond).
  Future<void> ensureAlive() async {
    if (state.status != TrackingStatus.active) return;
    final port = ref.read(locationTrackingPortProvider);
    final alive = await port.isActive();
    final stale = _isStale();
    if (alive && !stale) return;
    _log('tracking.revive', attrs: {'alive': alive, 'stale': stale});
    await port.stop();
    await _subscribe();
  }

  Future<void> stop(TrackingStopReason reason) async {
    if (state.status == TrackingStatus.stopped) return;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    await ref.read(locationTrackingPortProvider).stop();
    // Expédie ce qui reste en tampon avant de couper.
    await ref.read(positionReporterPortProvider).flush();
    state = state.copyWith(
      status: TrackingStatus.stopped,
      stopReason: reason,
    );
    _log('tracking.stopped', attrs: {'reason': reason.name});
  }

  /// Vide le tampon réseau (hook de pause du cycle de vie).
  Future<void> flush() => ref.read(positionReporterPortProvider).flush();

  /// (Re)abonne le capteur. Renvoie `false` si la plateforme refuse de démarrer
  /// le flux (l'exception est journalisée, pas propagée).
  Future<bool> _subscribe() async {
    await _sub?.cancel();
    try {
      final port = ref.read(locationTrackingPortProvider);
      final reporter = ref.read(positionReporterPortProvider);
      _sub = port.positions().listen(
        (pos) {
          unawaited(reporter.report(pos));
          _hasFix = true;
          _lastReportAt = DateTime.now();
          state = state.copyWith(
            status: TrackingStatus.active,
            fixCount: state.fixCount + 1,
            lastFixAt: pos.timestamp,
          );
        },
        onError: (Object e, StackTrace st) =>
            _log('tracking.stream_error', error: e, stack: st),
      );
      return true;
    } catch (e, st) {
      _log('tracking.subscribe_error', error: e, stack: st);
      return false;
    }
  }

  bool _isStale() {
    final last = state.lastFixAt;
    if (last == null) return false; // pas encore de point : on laisse le temps
    return DateTime.now().difference(last) > _staleAfter;
  }

  void _scheduleStopDeadline(DateTime? absolute) {
    _deadlineTimer?.cancel();
    final maxByDuration = DateTime.now().add(_safetyMaxDuration);
    // Effective = la plus proche entre la date limite et la durée max de sûreté.
    final effective = (absolute == null || maxByDuration.isBefore(absolute))
        ? maxByDuration
        : absolute;
    final remaining = effective.difference(DateTime.now());
    _deadlineTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => unawaited(stop(TrackingStopReason.deadline)),
    );
  }

  /// Démarre le battement périodique (présence d'une équipe à l'arrêt).
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _maybeHeartbeat());
  }

  void _maybeHeartbeat() {
    if (state.status != TrackingStatus.active || !_hasFix) return;
    final last = _lastReportAt;
    // Un point organique récent suffit : on ne bat que si l'équipe est immobile.
    if (last != null && DateTime.now().difference(last) < _heartbeatInterval) {
      return;
    }
    _lastReportAt = DateTime.now();
    unawaited(ref.read(positionReporterPortProvider).heartbeat());
    _log('tracking.heartbeat');
  }

  void _teardown() {
    _deadlineTimer?.cancel();
    _heartbeatTimer?.cancel();
    unawaited(_sub?.cancel());
  }

  void _log(
    String msg, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) {
    final logger = ref.read(loggerProvider);
    if (error != null) {
      logger.error(msg, attrs: attrs, error: error, stack: stack);
    } else {
      logger.info(msg, attrs: attrs);
    }
  }
}

final trackingServiceProvider =
    NotifierProvider<TrackingService, TrackingState>(TrackingService.new);
