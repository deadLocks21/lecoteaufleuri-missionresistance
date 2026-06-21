import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../domain/ports/location_tracking_port.dart';
import '../../domain/ports/position_reporter_port.dart';
import '../../domain/value_objects/gps_position.dart';
import '../memory/in_memory_position_reporter.dart';
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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final teamId = await FlutterForegroundTask.getData<String>(
          key: TrackingDataKeys.teamId,
        ) ??
        'unknown';
    _deadlineMillis = await FlutterForegroundTask.getData<int>(
          key: TrackingDataKeys.deadlineMillis,
        ) ??
        0;

    _tracker =
        GeolocatorLocationTracking(distanceFilterMeters: kDistanceFilterMeters);
    _reporter = kTrackingApiUrl.isEmpty
        ? InMemoryPositionReporter()
        : HttpPositionReporter(baseUrl: kTrackingApiUrl, teamId: teamId);

    // La permission a été accordée côté UI avant le démarrage du service.
    try {
      _sub = _tracker!.positions().listen(
        (pos) {
          _hasFix = true;
          _lastReportAt = DateTime.now();
          _reporter!.report(pos);
          // Remonte à l'UI (rafraîchit le compteur quand l'app est ouverte).
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

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_tick());

  Future<void> _tick() async {
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
