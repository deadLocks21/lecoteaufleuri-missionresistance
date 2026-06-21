import '../value_objects/gps_position.dart';

/// Source de position **côté appareil** (capteur GPS + service de suivi).
///
/// L'adapter réel s'appuie sur un service de premier plan (Android) / les mises
/// à jour en arrière-plan (iOS) pour continuer à émettre téléphone en poche
/// (cf. notes batterie/permissions). Le shipping réseau est l'affaire d'un port
/// distinct ([PositionReporterPort]) : ici on ne fait que **lire** la position.
abstract interface class LocationTrackingPort {
  /// Demande/escalade la permission de localisation (jusqu'à « toujours » pour
  /// l'arrière-plan). Renvoie `true` si le suivi peut démarrer.
  Future<bool> ensurePermission();

  /// Flux de positions. L'écoute démarre le service de suivi plateforme ;
  /// l'annulation de l'abonnement (ou [stop]) l'arrête.
  Stream<GpsPosition> positions();

  /// `true` tant que l'adapter pense le service plateforme actif. Indice de
  /// *liveness* (un OEM peut tuer le service sans qu'on le sache — d'où le
  /// recoupement avec la fraîcheur du dernier point côté service).
  Future<bool> isActive();

  /// Arrête le service de suivi plateforme (retire la notification Android).
  Future<void> stop();
}
