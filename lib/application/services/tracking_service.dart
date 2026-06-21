import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/telemetry/telemetry_providers.dart';
import '../../infrastructure/tracking/geolocator_location_tracking.dart';
import '../../infrastructure/tracking/tracking_config.dart';
import '../../infrastructure/tracking/tracking_task_handler.dart';
import '../session/session_controller.dart';

enum TrackingStatus { idle, active, stopped, denied, expired }

enum TrackingStopReason { manual, scenarioComplete, deadline }

/// État observable du suivi (pour l'UI / le debug). Le compteur de points est
/// alimenté par l'isolate d'arrière-plan quand l'app est ouverte.
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

/// Contrôleur (isolate UI) du suivi GPS. Le travail réel — capture GPS,
/// battement, envoi réseau — vit dans l'**isolate d'arrière-plan** de
/// `flutter_foreground_task` ([TrackingTaskHandler]), ce qui le fait survivre à
/// la fermeture de l'app. Ce service ne fait que :
///
/// - démarrer le service au déverrouillage (= début de jeu) ;
/// - l'arrêter (scénario terminé, reverrouillage ; la date limite est gérée
///   dans l'isolate) ;
/// - le relancer au retour au premier plan s'il a été tué ([ensureAlive]) ;
/// - refléter le compteur de points remonté par l'isolate.
class TrackingService extends Notifier<TrackingState> {
  static const int _serviceId = 4509;

  @override
  TrackingState build() {
    _initForegroundTask();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    ref.onDispose(
      () => FlutterForegroundTask.removeTaskDataCallback(_onTaskData),
    );

    // Le suivi suit le cycle de la session : déverrouillage = début de jeu,
    // reverrouillage (depuis l'app, pas le shake d'un mauvais code) = arrêt.
    ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
      if (next is Unlocked) {
        unawaited(start());
      } else if (next is Locked && prev is Unlocked) {
        unawaited(stop(TrackingStopReason.manual));
      }
    });
    if (ref.read(sessionControllerProvider) is Unlocked) {
      Future.microtask(start);
    }

    return const TrackingState(status: TrackingStatus.idle);
  }

  Future<void> start() async {
    if (state.status == TrackingStatus.active) return;

    final absolute = trackingConfiguredDeadline();
    if (absolute != null && DateTime.now().isAfter(absolute)) {
      state = const TrackingState(status: TrackingStatus.expired);
      _log('tracking.skipped_expired');
      return;
    }

    try {
      final granted =
          await GeolocatorLocationTracking.ensureLocationPermission();
      if (!granted) {
        state = const TrackingState(status: TrackingStatus.denied);
        _log('tracking.permission_denied');
        return;
      }
      await _ensureNotificationPermission();

      final ok = await _launch(absolute);
      state = ok
          ? TrackingState(
              status: TrackingStatus.active,
              startedAt: DateTime.now(),
            )
          : const TrackingState(status: TrackingStatus.denied);
      _log(ok ? 'tracking.started' : 'tracking.start_failed');
    } catch (e, st) {
      // Plateforme indisponible (canal absent en test, device exotique…) :
      // on dégrade proprement plutôt que de laisser fuir l'exception.
      state = const TrackingState(status: TrackingStatus.denied);
      _log('tracking.start_error', error: e, stack: st);
    }
  }

  /// Liveness — au retour au premier plan. Relance le service s'il devrait
  /// tourner mais a été tué (OEM agressif).
  Future<void> ensureAlive() async {
    if (state.status != TrackingStatus.active) return;
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await _launch(trackingConfiguredDeadline());
      _log('tracking.revived');
    } catch (e, st) {
      _log('tracking.revive_error', error: e, stack: st);
    }
  }

  Future<void> stop(TrackingStopReason reason) async {
    if (state.status == TrackingStatus.stopped) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e, st) {
      _log('tracking.stop_error', error: e, stack: st);
    }
    state = state.copyWith(
      status: TrackingStatus.stopped,
      stopReason: reason,
    );
    _log('tracking.stopped', attrs: {'reason': reason.name});
  }

  /// Démarre le service de premier plan avec la config de la partie. La date
  /// limite **effective** = la plus proche entre la date limite absolue et
  /// `now + kSafetyMaxDuration` ; elle est passée à l'isolate qui l'applique.
  Future<bool> _launch(DateTime? absolute) async {
    final maxByDuration = DateTime.now().add(kSafetyMaxDuration);
    final effective = (absolute == null || maxByDuration.isBefore(absolute))
        ? maxByDuration
        : absolute;

    final team = ref.read(currentTeamProvider);
    if (team == null) {
      // Pas d'équipe authentifiée : rien à suivre (ne devrait pas arriver, le
      // suivi ne démarre qu'au déverrouillage).
      _log('tracking.no_team');
      return false;
    }
    await FlutterForegroundTask.saveData(
      key: TrackingDataKeys.teamId,
      value: team.id,
    );
    await FlutterForegroundTask.saveData(
      key: TrackingDataKeys.deadlineMillis,
      value: effective.millisecondsSinceEpoch,
    );

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Suivi de position actif',
      notificationText: 'Le poste transmet sa position pendant le jeu.',
      callback: startTrackingCallback,
    );
    return result is ServiceRequestSuccess;
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mission_resistance_tracking',
        channelName: 'Suivi de position',
        channelDescription: 'Transmission de la position pendant le jeu.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(kHeartbeatInterval.inMilliseconds),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _ensureNotificationPermission() async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _onTaskData(Object data) {
    if (data is Map && data['event'] == 'fix') {
      final ts = data['ts'];
      state = state.copyWith(
        fixCount: state.fixCount + 1,
        lastFixAt: ts is int
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : state.lastFixAt,
      );
    }
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
