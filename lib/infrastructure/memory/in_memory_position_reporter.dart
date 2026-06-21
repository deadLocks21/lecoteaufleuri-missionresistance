import '../../domain/ports/position_reporter_port.dart';
import '../../domain/value_objects/gps_position.dart';

/// Jumeau InMemory de [PositionReporterPort] : conserve les positions en mémoire
/// vive au lieu de les poster. Utilisé quand aucun backend n'est configuré
/// (`TRACKING_API_URL` vide) et dans les tests — la trace reste inspectable via
/// [reported] sans réseau ni permission de fond.
class InMemoryPositionReporter implements PositionReporterPort {
  final List<GpsPosition> _reported = [];

  /// Vue en lecture seule des positions « envoyées ».
  List<GpsPosition> get reported => List.unmodifiable(_reported);

  /// Nombre de battements de cœur émis (inspectable en test).
  int heartbeats = 0;

  @override
  Future<void> report(GpsPosition position) async {
    _reported.add(position);
  }

  @override
  Future<void> heartbeat() async {
    heartbeats++;
  }

  @override
  Future<void> flush() async {
    // Rien à expédier : tout est déjà « livré » en mémoire.
  }
}
