/// Configuration du suivi GPS **partagée entre l'isolate UI et l'isolate
/// d'arrière-plan** (le handler de `flutter_foreground_task`). Volontairement
/// sans Riverpod ni Flutter pour rester importable des deux côtés.
library;

const String _kTrackingDeadlineRaw =
    String.fromEnvironment('TRACKING_DEADLINE');

/// Date limite d'émission absolue configurée au build (`null` si absente ou non
/// parsable). ISO 8601, ex. `2026-07-15T18:00:00+02:00`.
DateTime? trackingConfiguredDeadline() {
  if (_kTrackingDeadlineRaw.isEmpty) return null;
  return DateTime.tryParse(_kTrackingDeadlineRaw);
}

/// Distance minimale (m) entre deux points reportés — détermine aussi le rayon
/// de la « zone » dessinée sur la carte. Sur iOS, CoreLocation est configuré à
/// 0 m pour maintenir le Dart VM éveillé ; ce seuil est appliqué au niveau
/// applicatif avant d'envoyer une position au serveur.
const int kDistanceFilterMeters = 20;

/// Cadence du battement de cœur (équipe immobile). À garder **sous** le seuil
/// de fraîcheur serveur (`POSITION_STALE_AFTER_SECONDS`, 120 s par défaut).
const Duration kHeartbeatInterval = Duration(seconds: 45);

/// Garde-fou : arrêt automatique après cette durée même sans date limite
/// configurée (évite un poste qui émet pendant des jours).
const Duration kSafetyMaxDuration = Duration(hours: 4);

/// Clés du stockage partagé (`FlutterForegroundTask.saveData/getData`) — le
/// pont pour passer la config *runtime* à l'isolate d'arrière-plan.
abstract final class TrackingDataKeys {
  static const String teamId = 'tracking.teamId';

  /// Partie active (envoyée dans l'en-tête `X-Partie-Id`). Vide = aucune.
  static const String partieId = 'tracking.partieId';

  /// Date limite effective (epoch ms) ; `0` = aucune.
  static const String deadlineMillis = 'tracking.deadlineMillis';

  /// `true` sur iOS : le GPS tourne dans l'isolate UI (CoreLocation ne
  /// fonctionne pas dans l'isolate d'arrière-plan de flutter_foreground_task).
  static const String isIos = 'tracking.isIos';
}
