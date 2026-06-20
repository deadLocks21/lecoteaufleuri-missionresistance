/// Indice déchiffrable d'une mission.
class Clue {
  const Clue({required this.index, required this.text});

  /// Position 0-based dans la mission (= ordre de déverrouillage).
  final int index;

  /// Texte de l'indice révélé.
  final String text;
}

/// Mission du scénario : un titre et une liste ordonnée d'indices.
class Mission {
  const Mission({
    required this.index,
    required this.title,
    required this.clues,
  });

  /// Position 0-based dans le scénario.
  final int index;

  /// Titre affiché dans le stepper (ex. `Établir le contact`).
  final String title;

  /// Indices, dans l'ordre de déverrouillage.
  final List<Clue> clues;

  int get clueCount => clues.length;
}
