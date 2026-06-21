import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/ports/location_tracking_port.dart';
import '../../domain/value_objects/gps_position.dart';

/// Adapter réel de [LocationTrackingPort] via `geolocator` (gratuit, package
/// standard — pas de licence, cf. discussion de faisabilité).
///
/// - **Android** : `foregroundNotificationConfig` → l'écoute du flux tourne en
///   service de premier plan (notification permanente), donc continue téléphone
///   en poche.
/// - **iOS** : `allowBackgroundLocationUpdates` + le background mode `location`
///   de l'Info.plist + permission « Toujours ».
///
/// L'adapter **possède** l'abonnement capteur : [positions] le démarre (de façon
/// idempotente) et [stop] l'annule pour de bon — annuler l'abonnement arrête
/// aussi le service de premier plan Android.
class GeolocatorLocationTracking implements LocationTrackingPort {
  GeolocatorLocationTracking({this.distanceFilterMeters = 50});

  /// Distance minimale (m) entre deux points : suffisant pour « voir où est
  /// l'équipe » et bien plus doux pour la batterie qu'un flux continu.
  final int distanceFilterMeters;

  final StreamController<GpsPosition> _controller =
      StreamController<GpsPosition>.broadcast();
  StreamSubscription<Position>? _geoSub;
  bool _active = false;

  @override
  Future<bool> ensurePermission() async {
    // Le service système de localisation doit être activé (hors web).
    if (!kIsWeb) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    // « whileInUse » suffit au service de premier plan tant que l'app est
    // visible ; pour le vrai fond (poche, écran éteint) l'utilisateur doit
    // accorder « Toujours » dans les réglages (Android 11+ ne le propose pas en
    // popup). On démarre quand même avec ce qu'on a.
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  @override
  Stream<GpsPosition> positions() {
    if (!_active) _start();
    return _controller.stream;
  }

  void _start() {
    _active = true;
    _geoSub = Geolocator.getPositionStream(locationSettings: _buildSettings())
        .listen(
      (p) => _controller.add(_toDomain(p)),
      onError: (Object e, StackTrace st) => _controller.addError(e, st),
    );
  }

  @override
  Future<bool> isActive() async => _active;

  @override
  Future<void> stop() async {
    _active = false;
    await _geoSub?.cancel();
    _geoSub = null;
  }

  /// Ferme l'adapter (cycle de vie du container Riverpod / tests).
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  LocationSettings _buildSettings() {
    const accuracy = LocationAccuracy.high;
    if (kIsWeb) {
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Suivi de position actif',
            notificationText:
                'Le poste transmet sa position pendant le jeu.',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          activityType: ActivityType.fitness,
        );
      default:
        return LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
        );
    }
  }

  GpsPosition _toDomain(Position p) => GpsPosition(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        accuracyMeters: p.accuracy,
      );
}
