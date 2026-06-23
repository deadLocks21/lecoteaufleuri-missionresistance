import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:record/record.dart';

import '../tracking/geolocator_location_tracking.dart';

/// Demande **en une passe, au déverrouillage**, toutes les permissions dont le
/// poste a besoin pendant le jeu (localisation, micro, notifications), pour
/// éviter des dialogues surprise en pleine partie (BRIEF §2, §6).
///
/// **Best-effort** : un refus (ou l'absence de plugin en test/web) n'empêche pas
/// d'entrer dans l'app — chaque feature redemande/dégrade ensuite à l'usage
/// (`TrackingService.start`, `MicEmission.start`). Les demandes sont
/// **séquentielles** pour que les dialogues natifs s'enchaînent proprement.
class StartupPermissions {
  const StartupPermissions();

  Future<void> requestAll() async {
    await _requestLocation();
    await _requestMicrophone();
    await _requestNotifications();
  }

  Future<void> _requestLocation() async {
    try {
      await GeolocatorLocationTracking.ensureLocationPermission();
    } catch (_) {
      // Service de localisation coupé / plateforme indisponible : on ignore,
      // le suivi redemandera au démarrage de la partie.
    }
  }

  Future<void> _requestMicrophone() async {
    try {
      // `hasPermission()` de `record` déclenche le dialogue natif si besoin.
      await AudioRecorder().hasPermission();
    } catch (_) {
      // Pas de micro / plugin absent : l'émission radio dégradera à l'usage.
    }
  }

  Future<void> _requestNotifications() async {
    if (kIsWeb) return;
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // Plugin absent (test) : la notif du service de premier plan redemandera.
    }
  }
}
