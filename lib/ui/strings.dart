/// Catalogue de textes (copy) — centralisé pour la parité (BRIEF §11, §16).
abstract final class Strings {
  // Plaque d'identité
  static const model = 'Poste Émetteur-Récepteur';
  static const locked = 'VERROUILLÉ';

  // Écran de verrouillage
  static const lockPrompt = "Saisissez le code d'accès du poste";
  static const codePlaceholder = '• • • •';
  static const unlock = 'Déverrouiller';
  static const lockHintIdle = '— en attente du code —';
  static const lockHintOk = 'Poste déverrouillé — bienvenue';
  static const lockHintBad = 'CODE INCORRECT — réessayez';
  static const lockHintNetwork = 'RÉSEAU INDISPONIBLE — réessayez';

  // Onglets
  static const tabRadio = 'Radio';
  static const tabCarnet = 'Carnet';

  // Bandeau LCD — défauts
  static String tickerRadio(String channel) =>
      'TRAFIC RADIO — FRÉQ. $channel — PRÊT À ÉMETTRE';
  static String tickerMission(
    int number,
    int total,
    String title,
    int unlocked,
    int clueCount,
  ) =>
      'MISSION $number/$total — ${title.toUpperCase()} — '
      '$unlocked/$clueCount INDICE${clueCount > 1 ? 'S' : ''}';

  // Émission
  static const sectionEmission = 'Émission';
  static const vuLabel = "NIVEAU D'ÉMISSION";
  static const transmit = 'TRANSMETTRE';
  static const transmitting = 'ÉMISSION…';
  static const pttHint = 'Maintenir pour parler · relâcher pour envoyer';
  static String pttRecording(int seconds) =>
      'Enregistrement  0:${seconds.toString().padLeft(2, '0')}';
  static String pttSent(int seconds) => 'Message envoyé (${seconds}s) ✓';
  static const tickerTxLive = '▶ ÉMISSION EN COURS — micro ouvert';
  static String tickerTxSent(int seconds) =>
      '✓ MESSAGE ÉMIS (${seconds}s) — reçu par les autres postes';

  // Appel QG
  static const appel = 'APPEL QG';
  static const appelHelp = "— demander de l'aide";
  static const appelInProgress = '— appel en cours…';
  static const tickerAppel = '⚑ APPEL DU QG — ouverture du composeur…';

  // Réception
  static const sectionReception = 'Réception · les plus récents en haut';
  static const badgeNew = 'NOUVEAU';
  static const badgeReplay = '↺ réécouter';
  static String tickerPlaying(String from) => '♪ LECTURE — $from';
  static String tickerPlayed(String from) => '✓ LECTURE TERMINÉE — $from';

  // Carnet de mission
  static const carnetTitle = 'Carnet de mission';
  static const progression = 'Progression';
  static const tagDone = 'TERMINÉE';
  static const tagCurrent = 'EN COURS';
  static const tagUpcoming = 'À VENIR';
  static String clueCover(int number) => 'INDICE $number';
  static String clueLabel(int number) => 'Indice $number';
  static const coverDecipher = 'toucher pour déchiffrer';
  static const coverLocked = 'verrouillé';
  static const coverDeciphered = 'déchiffré';
  static const coverReview = 'toucher pour revoir';
  static String clueCount(int unlocked, int total) =>
      '$unlocked / $total indices déchiffrés';
  static const missionDone = 'Mission accomplie';
  static String tickerClueDeciphered(int number) => '▸ INDICE $number DÉCHIFFRÉ';
  static const tickerMissionDone = '✓ MISSION ACCOMPLIE';
  static const tickerScenarioDone = '✓ SCÉNARIO TERMINÉ';

  // Modal de confirmation
  static const modalTitle = "Déchiffrer l'indice ?";
  static String modalMessage(int number) =>
      "Es-tu sûr de vouloir déchiffrer l'indice $number ?";
  static const cancel = 'Annuler';
  static const decipher = 'Déchiffrer';

  // Accessibilité
  static const a11yTitle = 'Poste radio TSF — application de jeu';
}
