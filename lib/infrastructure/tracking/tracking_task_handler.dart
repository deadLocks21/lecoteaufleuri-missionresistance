import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/location_tracking_port.dart';
import '../../domain/ports/position_reporter_port.dart';
import '../../domain/value_objects/gps_position.dart';
import '../http/api_config.dart';
import '../http/api_headers.dart';
import '../memory/in_memory_position_reporter.dart';
import '../notifications/local_notifier.dart';
import '../radio/http_inbox.dart';
import '../radio/radio_json.dart';
import 'geolocator_location_tracking.dart';
import 'http_position_reporter.dart';
import 'tracking_config.dart';

/// Point d'entrée de l'isolate d'arrière-plan. **Doit** être une fonction
/// top-level annotée `@pragma('vm:entry-point')` (sinon l'AOT l'élague).
@pragma('vm:entry-point')
void startTrackingCallback() {
  // Enregistre les plugins (geolocator, shared_preferences…) dans cet isolate.
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}

/// Exécute le suivi dans l'isolate du service de premier plan → il **continue
/// app fermée / écran éteint**. Réutilise les mêmes adapters que l'UI
/// ([LocationTrackingPort] / [PositionReporterPort]).
///
/// - le flux GPS (distance-filtré) émet un point → on l'envoie ;
/// - [onRepeatEvent] (toutes [kHeartbeatInterval]) gère le **battement** quand
///   l'équipe est immobile et la **2ᵉ sécurité d'arrêt** (date limite).
class TrackingTaskHandler extends TaskHandler {
  LocationTrackingPort? _tracker;
  PositionReporterPort? _reporter;
  StreamSubscription<GpsPosition>? _sub;
  DateTime? _lastReportAt;
  bool _hasFix = false;
  int _deadlineMillis = 0;

  // Sur iOS, le GPS et le heartbeat tournent dans l'isolate UI (CoreLocation
  // n'émet pas depuis un isolate d'arrière-plan). Cet handler ne gère alors
  // que la veille radio et les notifications.
  bool _isIos = false;

  // Radio : ce handler est le **seul poller** des messages pendant la partie.
  // Il notifie (messages reçus) et pousse tout nouveau message à l'UI.
  HttpInbox? _inbox;
  StreamSubscription<RadioMessage>? _radioSub;
  LocalNotifier? _notifier;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Isolate de fond : ses statiques sont distinctes de l'UI, on recharge donc
    // l'identifiant d'appareil pour que GPS/radio portent aussi `X-Device-Id`.
    await DeviceId.ensureLoaded();

    final teamId = await FlutterForegroundTask.getData<String>(
          key: TrackingDataKeys.teamId,
        ) ??
        'unknown';
    final rawPartieId = await FlutterForegroundTask.getData<String>(
      key: TrackingDataKeys.partieId,
    );
    final partieId =
        (rawPartieId == null || rawPartieId.isEmpty) ? null : rawPartieId;
    _deadlineMillis = await FlutterForegroundTask.getData<int>(
          key: TrackingDataKeys.deadlineMillis,
        ) ??
        0;
    _isIos = await FlutterForegroundTask.getData<bool>(
          key: TrackingDataKeys.isIos,
        ) ??
        false;

    if (!_isIos) {
      // Android : GPS et envoi HTTP dans cet isolate d'arrière-plan.
      _tracker = GeolocatorLocationTracking(
          distanceFilterMeters: kDistanceFilterMeters);
      _reporter = kApiBaseUrl.isEmpty
          ? InMemoryPositionReporter()
          : HttpPositionReporter(
              baseUrl: kApiBaseUrl,
              teamId: teamId,
              partieId: partieId,
              onPartieFinished: _onPartieFinished,
            );
      try {
        _sub = _tracker!.positions().listen(
          (pos) {
            _hasFix = true;
            _lastReportAt = DateTime.now();
            _reporter!.report(pos);
            FlutterForegroundTask.sendDataToMain(<String, Object>{
              'event': 'fix',
              'ts': pos.timestamp.millisecondsSinceEpoch,
            });
          },
          onError: (Object e, StackTrace st) => developer.log(
            'tracking(bg): erreur de flux',
            name: 'mission_resistance.tracking',
            error: e,
            stackTrace: st,
          ),
        );
      } catch (e, st) {
        developer.log(
          'tracking(bg): démarrage du flux impossible',
          name: 'mission_resistance.tracking',
          error: e,
          stackTrace: st,
        );
      }
    }

    // Sur iOS le radio watch tourne dans l'isolate UI (TrackingService) car le
    // background isolate n'est pas maintenu en vie par CoreLocation.
    if (!_isIos) await _startRadioWatch(teamId, partieId);
  }

  /// Démarre la veille radio : `fetch()` **amorce** le set des ids déjà vus pour
  /// ne pas notifier le backlog existant, puis le flux `incoming()` (sondage
  /// ~8 s) émet les nouveaux messages → notification (reçus uniquement) + push à
  /// l'UI. Sans backend (démo) : pas de service de fond → rien à faire ici.
  Future<void> _startRadioWatch(String teamId, String? partieId) async {
    if (kApiBaseUrl.isEmpty) return;
    try {
      _notifier = LocalNotifier();
      final inbox =
          HttpInbox(baseUrl: kApiBaseUrl, teamId: teamId, partieId: partieId);
      _inbox = inbox;
      // Amorçage best-effort : en cas d'échec réseau, le 1er sondage (dans ~8 s)
      // rejouera la liste ; le serveur plafonne à 50 messages, donc pas de
      // tempête de notifications même dans ce cas dégradé.
      try {
        await inbox.fetch();
      } catch (_) {/* amorçage best-effort */}
      _radioSub = inbox.incoming().listen(
        _onRadioMessage,
        onError: (Object e, StackTrace st) => developer.log(
          'tracking(bg): erreur de veille radio',
          name: 'mission_resistance.tracking',
          error: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      developer.log(
        'tracking(bg): veille radio impossible',
        name: 'mission_resistance.tracking',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onRadioMessage(RadioMessage message) {
    // Remonte le message à l'UI (mise à jour live quand l'app est ouverte).
    FlutterForegroundTask.sendDataToMain(radioMessageToData(message));
    // On ne notifie que les messages **reçus** (pas l'écho de ses propres
    // émissions, déjà affichées « ÉMIS » côté UI).
    if (!message.mine) {
      unawaited(
        _notifier?.showNewMessage(
              messageId: message.id.value,
              sender: message.sender,
            ) ??
            Future<void>.value(),
      );
    }
  }

  /// Partie terminée (le backend a renvoyé `410`) : on prévient l'isolate UI
  /// (qui reflète « partie terminée »), on poste une notification locale pour
  /// ramener le joueur, puis on arrête le service de premier plan.
  void _onPartieFinished() {
    FlutterForegroundTask.sendDataToMain(<String, Object>{
      'event': 'partie_ended',
    });
    unawaited(_notifyEndedThenStop());
  }

  /// Notifie la fin de partie **avant** de couper le service (sinon l'isolate
  /// peut être tué avant que la notification ne parte).
  Future<void> _notifyEndedThenStop() async {
    try {
      await (_notifier ??= LocalNotifier()).showPartieEnded();
    } catch (_) {
      // Notification best-effort : on arrête le service quoi qu'il arrive.
    }
    await FlutterForegroundTask.stopService();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_tick());

  Future<void> _tick() async {
    // Sur iOS, le heartbeat et la deadline sont gérés dans l'isolate UI.
    if (_isIos) return;

    // 2ᵉ sécurité d'arrêt : date limite (vérifiée même app fermée).
    if (_deadlineMillis > 0 &&
        DateTime.now().millisecondsSinceEpoch >= _deadlineMillis) {
      await _reporter?.flush();
      await FlutterForegroundTask.stopService();
      return;
    }
    // Battement : équipe immobile (aucun point récent) → signale la présence.
    final last = _lastReportAt;
    if (_hasFix &&
        (last == null ||
            DateTime.now().difference(last) >= kHeartbeatInterval)) {
      _lastReportAt = DateTime.now();
      await _reporter?.heartbeat();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _radioSub?.cancel();
    _radioSub = null;
    _inbox?.dispose();
    _inbox = null;
    await _sub?.cancel();
    _sub = null;
    await _reporter?.flush();
    final tracker = _tracker;
    if (tracker is GeolocatorLocationTracking) {
      await tracker.dispose();
    }
    final reporter = _reporter;
    if (reporter is HttpPositionReporter) {
      await reporter.dispose();
    }
  }
}
