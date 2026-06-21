/// Un point de la trace d'une équipe : coordonnées + horodatage de la prise.
///
/// Value object immuable. `timestamp` est l'instant de la mesure côté appareil ;
/// le serveur conserve en plus son propre `receivedAt` (la dérive d'horloge du
/// téléphone ne doit pas fausser la fraîcheur côté QG).
class GpsPosition {
  const GpsPosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Précision horizontale estimée en mètres (`null` si inconnue).
  final double? accuracyMeters;

  /// Forme de fil attendue par l'API (`POST /sessions/:team/positions`).
  Map<String, Object?> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ts': timestamp.millisecondsSinceEpoch,
        if (accuracyMeters != null) 'accuracy': accuracyMeters,
      };

  @override
  bool operator ==(Object other) =>
      other is GpsPosition &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timestamp == timestamp &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, timestamp, accuracyMeters);
}
