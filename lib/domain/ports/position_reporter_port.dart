import '../value_objects/gps_position.dart';

/// Expédition des positions vers le backend (`POST /sessions/:team/positions`).
///
/// L'implémentation réseau bufferise et envoie par lots avec retry hors-ligne :
/// une colo peut être hors couverture sur le terrain, les points partent quand
/// le réseau revient (le besoin est de revoir la trace *plus tard*, pas en
/// temps réel strict). Mode best-effort : ne lève jamais vers l'appelant.
abstract interface class PositionReporterPort {
  /// Met un point en file d'attente d'expédition.
  Future<void> report(GpsPosition position);

  /// Signale au backend que l'équipe est toujours là **sans nouveau point**
  /// (équipe à l'arrêt) : rafraîchit la fraîcheur côté carte sans polluer la
  /// trace. Best-effort — un battement raté n'est pas réessayé.
  Future<void> heartbeat();

  /// Force l'envoi du tampon (hooks de cycle de vie : pause, arrêt du suivi).
  Future<void> flush();
}
