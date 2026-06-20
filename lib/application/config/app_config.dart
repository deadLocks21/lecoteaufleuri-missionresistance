/// Paramètres configurables du poste (BRIEF §3). En natif, le **code**
/// déterminera l'équipe et son contenu ; ici les valeurs de démo du prototype.
class TsfConfig {
  const TsfConfig({
    required this.accessCode,
    required this.teamName,
    required this.teamChannel,
    required this.telQg,
  });

  /// Code d'accès (comparaison insensible à la casse + `trim()`).
  final String accessCode;

  /// Nom d'équipe affiché après déverrouillage.
  final String teamName;

  /// Fréquence / canal affiché dans le bandeau.
  final String teamChannel;

  /// Numéro appelé par APPEL QG (format international, sans espaces).
  final String telQg;

  /// Valeurs de démo (placeholders du prototype).
  static const TsfConfig demo = TsfConfig(
    accessCode: '6450',
    teamName: 'LES RENARDS',
    teamChannel: '6 450 kHz',
    telQg: '+33700000000',
  );
}
