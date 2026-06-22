/// Partie (session de jeu) en cours pour le groupe de l'équipe. Son `id` est
/// renvoyé au login et joint à chaque action (en-tête `X-Partie-Id`). La régie
/// la démarre / l'arrête ; quand elle s'arrête, le backend rejette les actions
/// (`410`) et l'app bascule en « partie terminée ».
class Partie {
  const Partie({required this.id, this.label});

  final String id;

  /// Libellé lisible (ex. « Partie du 22/06 14:30 »), purement informatif.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is Partie && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}
