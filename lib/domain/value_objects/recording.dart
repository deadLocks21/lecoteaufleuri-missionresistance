/// Enregistrement vocal capturé localement, prêt à être diffusé (uploadé).
///
/// Valeur produite par `EmissionPort.stop` et consommée par `OutboxPort.send`.
/// [path] localise le fichier audio temporaire ; l'adapter d'envoi le lit puis
/// le supprime. Un `null` côté capture signifie qu'aucun audio n'a été
/// enregistré (jumeau de démo ou permission micro refusée).
class Recording {
  const Recording({
    required this.path,
    required this.duration,
    required this.contentType,
  });

  /// Chemin du fichier audio temporaire sur l'appareil.
  final String path;

  final Duration duration;

  /// Type MIME du conteneur (ex. `audio/mp4` pour de l'AAC-LC en `.m4a`).
  final String contentType;
}
