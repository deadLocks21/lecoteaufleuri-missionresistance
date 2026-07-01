/// Destinataire d'une émission **choisi** par un poste central / nazi : soit
/// **tout le monde**, soit une **équipe précise**. Un poste portable n'en choisit
/// pas (le serveur impose « vers les postes centraux »), il émet sans `target`.
sealed class MessageTarget {
  const MessageTarget();

  /// Diffusion à tout le monde.
  static const MessageTarget all = AllTarget._();

  /// Équipe précise (par [id] ; [name] pour l'affichage du sélecteur).
  const factory MessageTarget.team(String id, String name) = TeamTarget;

  /// Valeur transmise au backend (champ multipart `target` : `'all'` ou l'uuid
  /// de l'équipe visée).
  String get wire;
}

/// Diffusion à tout le monde.
class AllTarget extends MessageTarget {
  const AllTarget._();

  @override
  String get wire => 'all';

  @override
  bool operator ==(Object other) => other is AllTarget;

  @override
  int get hashCode => 'all'.hashCode;
}

/// Une équipe précise du groupe.
class TeamTarget extends MessageTarget {
  const TeamTarget(this.id, this.name);

  final String id;
  final String name;

  @override
  String get wire => id;

  @override
  bool operator ==(Object other) =>
      other is TeamTarget && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
