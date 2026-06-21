import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/location_tracking_port.dart';
import '../../domain/ports/position_reporter_port.dart';
import '../di.dart';
import '../memory/in_memory_position_reporter.dart';
import 'geolocator_location_tracking.dart';
import 'http_position_reporter.dart';

/// Câblage du suivi GPS (sélection d'adapter + config au build), sur le même
/// modèle que `telemetry_providers.dart` : tout ce qui dépend du build
/// (dart-define) vit ici, le service applicatif ne voit que des providers.

/// Base d'API du backend de suivi, ex.
/// `https://mission-resistance-api.example.com` ou `http://10.0.2.2:3000`
/// (émulateur Android → hôte). **Vide → pas de réseau** : on stocke en mémoire
/// (jumeau `InMemoryPositionReporter`), pratique en dev.
///
/// Passé via :
/// `flutter run --dart-define=TRACKING_API_URL=https://…`
const String _kTrackingApiUrl = String.fromEnvironment('TRACKING_API_URL');

/// Date limite d'émission absolue (ISO 8601), ex. `2026-07-15T18:00:00+02:00`.
/// Au-delà, le suivi ne démarre pas / s'arrête (2ᵉ sécurité après « scénario
/// terminé »). Vide → seule la durée max de sûreté s'applique.
///
/// `flutter run --dart-define=TRACKING_DEADLINE=2026-07-15T18:00:00+02:00`
const String _kTrackingDeadline = String.fromEnvironment('TRACKING_DEADLINE');

/// Date limite résolue (`null` si non configurée ou non parsable).
final trackingDeadlineProvider = Provider<DateTime?>((ref) {
  if (_kTrackingDeadline.isEmpty) return null;
  return DateTime.tryParse(_kTrackingDeadline);
});

/// Capteur de position côté appareil. `Provider` simple → gardé vivant tant que
/// le container existe (l'adapter tient un `StreamController` + un abonnement
/// capteur qu'il serait coûteux de recréer).
final locationTrackingPortProvider = Provider<LocationTrackingPort>((ref) {
  final tracker = GeolocatorLocationTracking();
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Expéditeur des positions : HTTP si une base d'API est configurée, sinon le
/// jumeau en mémoire (cf. `kUseFakes` dans `di.dart`).
final positionReporterPortProvider = Provider<PositionReporterPort>((ref) {
  if (_kTrackingApiUrl.isEmpty) {
    return InMemoryPositionReporter();
  }
  final team = ref.watch(demoTeamProvider);
  final reporter = HttpPositionReporter(
    baseUrl: _kTrackingApiUrl,
    teamId: team.id,
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});
