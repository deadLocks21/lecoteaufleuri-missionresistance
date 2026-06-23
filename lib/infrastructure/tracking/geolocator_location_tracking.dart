import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/ports/location_tracking_port.dart';
import '../../domain/value_objects/gps_position.dart';

/// Adapter réel de [LocationTrackingPort] via `geolocator` (gratuit, package
/// standard — pas de licence, cf. discussion de faisabilité).
///
/// Tourne dans l'**isolate d'arrière-plan** de `flutter_foreground_task` : c'est
/// lui qui fournit le service de premier plan (notification permanente). On ne
/// met donc **pas** de `foregroundNotificationConfig` ici (sinon double
/// service / double notif). iOS conserve `allowBackgroundLocationUpdates` + le
/// background mode `location` de l'Info.plist.
///
/// L'adapter **possède** l'abonnement capteur : [positions] le démarre (de façon
/// idempotente) et [stop] l'annule.
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
  Future<bool> ensurePermission() => ensureLocationPermission();

  /// Demande/escalade la permission de localisation. **Statique** pour être
  /// appelée côté UI (où l'utilisateur peut répondre au dialogue) sans
  /// instancier l'adapter, qui vit lui dans l'isolate d'arrière-plan.
  ///
  /// « whileInUse » suffit : tant que le service de premier plan tourne, l'app
  /// est « en cours d'utilisation » et la localisation continue en poche. Le
  /// « Toujours » reste un bonus de robustesse (à accorder dans les réglages).
  static Future<bool> ensureLocationPermission() async {
    if (!kIsWeb) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
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
        // Pas de foregroundNotificationConfig : le service de premier plan est
        // fourni par flutter_foreground_task (sinon double service / notif).
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilterMeters,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          activityType: ActivityType.other,
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
