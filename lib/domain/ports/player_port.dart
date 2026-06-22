/// Lecture d'un clip audio distant (réception radio, BRIEF §8.2). Le jumeau de
/// démo n'est pas requis : sans backend les messages n'ont pas d'`audioUrl` et
/// la lecture est simulée par un délai.
abstract interface class PlayerPort {
  /// Joue l'audio à [url] ; complète à la **fin** de la lecture. [onPlaying]
  /// est invoqué quand le son démarre réellement (clip chargé/bufferisé),
  /// pour distinguer le chargement de la lecture côté UI.
  Future<void> play(String url, {void Function()? onPlaying});

  /// Interrompt la lecture en cours, le cas échéant.
  Future<void> stop();
}
