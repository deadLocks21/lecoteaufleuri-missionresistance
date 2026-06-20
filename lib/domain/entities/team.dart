/// Équipe résolue à partir du code d'accès (BRIEF §13.3).
class Team {
  const Team({required this.id, required this.name, required this.channel});

  final String id;

  /// Nom affiché sur la plaque après déverrouillage (ex. `LES RENARDS`).
  final String name;

  /// Fréquence / canal affiché dans le bandeau (ex. `6 450 kHz`).
  final String channel;

  @override
  bool operator ==(Object other) =>
      other is Team &&
      other.id == id &&
      other.name == name &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(id, name, channel);
}
