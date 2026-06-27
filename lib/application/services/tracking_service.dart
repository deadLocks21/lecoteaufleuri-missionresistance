import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:geolocator/geolocator.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/value_objects/gps_position.dart';
import '../../infrastructure/http/api_config.dart';
import '../../infrastructure/notifications/local_notifier.dart';
import '../../infrastructure/radio/http_inbox.dart';
import '../../infrastructure/telemetry/telemetry_providers.dart';
import '../../infrastructure/tracking/geolocator_location_tracking.dart';
import '../../infrastructure/tracking/http_position_reporter.dart';
import '../../infrastructure/tracking/tracking_config.dart';
import '../../infrastructure/tracking/tracking_task_handler.dart';
import '../session/partie_controller.dart';
import '../session/session_controller.dart';
import 'inbox_service.dart';

enum TrackingStatus { idle, active, stopped, denied, expired }

enum TrackingStopReason { manual, scenarioComplete, deadline, partieEnded }

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

  /// Partie pour laquelle le service tourne actuellement (détecte un changement
  /// de partie → relance avec le nouvel `X-Partie-Id`).
  String? _activePartieId;

  // ── iOS uniquement ───────────────────────────────────────────────────────
  // CoreLocation ne fonctionne pas dans l'isolate d'arrière-plan de
  // flutter_foreground_task. On fait donc tourner le GPS et l'envoi HTTP
  // directement dans l'isolate UI (qui reste vivant grâce au background mode
  // `location` de l'Info.plist).
  //
  // Le tracker iOS utilise distanceFilter=0 pour que CoreLocation réveille le
  // Dart VM en continu (sans ça, iOS suspend le VM si l'équipe est stationnaire
  // > ~10 min). Le filtrage des envois HTTP est appliqué ici (kDistanceFilterMeters).
  GeolocatorLocationTracking? _iosTracker;
  HttpPositionReporter? _iosReporter;
  StreamSubscription<dynamic>? _iosSub;
  Timer? _iosHeartbeatTimer;
  GpsPosition? _iosLastReportedPos;
  HttpInbox? _iosInbox;
  StreamSubscription<RadioMessage>? _iosRadioSub;

  @override
  TrackingState build() {
    _initForegroundTask();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    ref.onDispose(
      () => FlutterForegroundTask.removeTaskDataCallback(_onTaskData),
    );

    // Le suivi suit l'état de **partie** : il démarre quand une partie est en
    // cours (`PartiePlaying`) et s'arrête dès qu'elle se termine / change d'état
    // (verrouillage, déconnexion). Un **changement d'id** de partie (relance
    // depuis la régie) relance le service avec le nouvel `X-Partie-Id`.
    ref.listen<PartieState>(partieControllerProvider, (prev, next) {
      final prevId = prev is PartiePlaying ? prev.partie.id : null;
      final nextId = next is PartiePlaying ? next.partie.id : null;
      if (prevId == nextId) return;
      if (nextId != null) {
        unawaited(start());
      } else {
        unawaited(stop(TrackingStopReason.partieEnded));
      }
    });
    if (ref.read(partieControllerProvider) is PartiePlaying) {
      Future.microtask(start);
    }

    return const TrackingState(status: TrackingStatus.idle);
  }

  Future<void> start() async {
    final partieId = ref.read(currentPartieIdProvider);
    // Pas de partie active → rien à suivre (le GPS ne tourne qu'en partie).
    if (partieId == null) return;
    // Déjà actif pour cette même partie → rien à faire.
    if (state.status == TrackingStatus.active && _activePartieId == partieId) {
      return;
    }
    // Partie différente (relance régie) : on coupe le service en cours avant de
    // relancer avec le nouvel id.
    if (state.status == TrackingStatus.active) {
      await _stopService();
    }

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
      if (ok) _activePartieId = partieId;
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
    await _stopService();
    _activePartieId = null;
    state = state.copyWith(
      status: TrackingStatus.stopped,
      stopReason: reason,
    );
    _log('tracking.stopped', attrs: {'reason': reason.name});
  }

  /// Arrête le service de premier plan s'il tourne (sans toucher à l'état) —
  /// partagé par [stop] et la relance sur changement de partie.
  Future<void> _stopService() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _stopIosTracking();
    }
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e, st) {
      _log('tracking.stop_error', error: e, stack: st);
    }
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
      key: TrackingDataKeys.partieId,
      value: ref.read(currentPartieIdProvider) ?? '',
    );
    await FlutterForegroundTask.saveData(
      key: TrackingDataKeys.deadlineMillis,
      value: effective.millisecondsSinceEpoch,
    );
    await FlutterForegroundTask.saveData(
      key: TrackingDataKeys.isIos,
      value: defaultTargetPlatform == TargetPlatform.iOS,
    );

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Suivi de position actif',
      notificationText: 'Le poste transmet sa position pendant le jeu.',
      callback: startTrackingCallback,
    );
    if (result is ServiceRequestFailure) {
      _log('tracking.launch_rejected', error: result.error);
    }
    final ok = result is ServiceRequestSuccess;
    if (ok && defaultTargetPlatform == TargetPlatform.iOS) {
      await _startIosTracking(team.id, ref.read(currentPartieIdProvider), effective);
    }
    return ok;
  }

  // ── iOS : GPS + envoi HTTP dans l'isolate UI ─────────────────────────────

  Future<void> _startIosTracking(
    String teamId,
    String? partieId,
    DateTime deadline,
  ) async {
    // distanceFilter=0 : CoreLocation réveille le Dart VM à chaque fix (~2-3s)
    // même en stationnaire, évitant la suspension iOS après ~10 min. Les envois
    // HTTP sont filtrés en aval (kDistanceFilterMeters).
    _iosTracker = GeolocatorLocationTracking(distanceFilterMeters: 0);
    _iosLastReportedPos = null;
    if (kApiBaseUrl.isNotEmpty) {
      _iosReporter = HttpPositionReporter(
        baseUrl: kApiBaseUrl,
        teamId: teamId,
        partieId: partieId,
        onPartieFinished: _onIosPartieFinished,
      );
    }
    _iosSub = _iosTracker!.positions().listen(
      (pos) {
        final last = _iosLastReportedPos;
        final dist = last == null
            ? double.infinity
            : Geolocator.distanceBetween(
                last.latitude, last.longitude,
                pos.latitude, pos.longitude,
              );
        if (dist >= kDistanceFilterMeters) {
          _iosLastReportedPos = pos;
          _iosReporter?.report(pos);
        }
        state = state.copyWith(
          fixCount: state.fixCount + 1,
          lastFixAt: pos.timestamp,
        );
      },
      onError: (Object e, StackTrace st) =>
          _log('tracking.ios_gps_error', error: e, stack: st),
    );
    _iosHeartbeatTimer =
        Timer.periodic(kHeartbeatInterval, (_) => _iosHeartbeat(deadline));
    _log('tracking.ios_gps_started');

    // Radio watch dans l'isolate UI : le background isolate n'est pas maintenu
    // en vie par CoreLocation sur iOS, donc les messages et notifications ne
    // parviendraient jamais depuis le handler de fond.
    if (kApiBaseUrl.isNotEmpty) {
      final inbox = HttpInbox(baseUrl: kApiBaseUrl, teamId: teamId, partieId: partieId);
      _iosInbox = inbox;
      try {
        await inbox.fetch();
      } catch (_) {}
      final notifier = LocalNotifier();
      _iosRadioSub = inbox.incoming().listen(
        (message) {
          if (!message.mine) {
            unawaited(notifier.showNewMessage(
              messageId: message.id.value,
              sender: message.sender,
            ));
          }
          try {
            ref.read(inboxServiceProvider.notifier).addReceived(message);
          } catch (_) {}
        },
        onError: (Object e, StackTrace st) =>
            _log('tracking.ios_radio_error', error: e, stack: st),
      );
    }
  }

  Future<void> _stopIosTracking() async {
    _iosHeartbeatTimer?.cancel();
    _iosHeartbeatTimer = null;
    await _iosSub?.cancel();
    _iosSub = null;
    _iosLastReportedPos = null;
    await _iosRadioSub?.cancel();
    _iosRadioSub = null;
    _iosInbox?.dispose();
    _iosInbox = null;
    await _iosReporter?.dispose();
    _iosReporter = null;
    final tracker = _iosTracker;
    if (tracker != null) {
      await tracker.dispose();
      _iosTracker = null;
    }
  }

  void _iosHeartbeat(DateTime deadline) {
    if (DateTime.now().isAfter(deadline)) {
      unawaited(stop(TrackingStopReason.deadline));
      return;
    }
    unawaited(_iosReporter?.heartbeat());
  }

  void _onIosPartieFinished() {
    unawaited(stop(TrackingStopReason.partieEnded));
    unawaited(ref.read(partieControllerProvider.notifier).refresh());
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
    if (data is! Map) return;
    switch (data['event']) {
      case 'fix':
        final ts = data['ts'];
        state = state.copyWith(
          fixCount: state.fixCount + 1,
          lastFixAt: ts is int
              ? DateTime.fromMillisecondsSinceEpoch(ts)
              : state.lastFixAt,
        );
      case 'partie_ended':
        // L'isolate a reçu un `410` : la partie est terminée. On reflète l'arrêt
        // et on demande au contrôleur de partie de réconcilier (→ « terminée »,
        // ou « en jeu » si la régie a relancé une nouvelle partie).
        unawaited(stop(TrackingStopReason.partieEnded));
        unawaited(ref.read(partieControllerProvider.notifier).refresh());
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
