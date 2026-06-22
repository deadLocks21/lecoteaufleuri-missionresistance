import 'dart:math' as math;

/// Durées & cadences exactes du prototype (BRIEF §12, design-tokens `durationMs`).
/// Centralisées pour la parité ; les courbes d'easing (type Flutter) vivent côté
/// UI (`ui/theme/app_curves.dart`).
abstract final class Timings {
  /// Enfoncement des touches (kbtn/ptt/appel).
  static const press = Duration(milliseconds: 60);

  /// Transition douce de l'aiguille du VU-mètre.
  static const vuTransition = Duration(milliseconds: 90);

  /// Rafraîchissement du niveau VU pendant l'émission.
  static const vuTick = Duration(milliseconds: 110);

  /// Glissement de la manette de l'interrupteur à bascule.
  static const toggle = Duration(milliseconds: 200);

  /// Animation d'erreur du champ de code.
  static const shake = Duration(milliseconds: 400);

  /// Retournement 3D d'une carte-indice.
  static const flip = Duration(milliseconds: 600);

  /// Re-rendu du carnet après déchiffrement.
  static const carnetRerender = Duration(milliseconds: 650);

  /// Pulsation du voyant rouge (PTT live).
  static const pttLivePulse = Duration(milliseconds: 700);

  /// Boucle de l'égaliseur d'un message en lecture.
  static const equalizer = Duration(milliseconds: 700);

  /// Pulsation du bouton APPEL QG « armé ».
  static const appelPulse = Duration(milliseconds: 800);

  /// Transition de déverrouillage vers l'app.
  static const unlock = Duration(milliseconds: 750);

  /// Clignotement du curseur du bandeau LCD.
  static const blink = Duration(seconds: 1);

  /// Sondage de l'état de partie (début/fin) — aligné sur le suivi régie (~10 s).
  static const partiePoll = Duration(seconds: 10);

  /// Retour au texte par défaut du bandeau après un message transitoire.
  static const tickerRevert = Duration(milliseconds: 1800);

  /// Reset de l'état « armé » du bouton APPEL QG.
  static const appelReset = Duration(milliseconds: 2500);

  /// Reset du sous-titre du PTT après envoi.
  static const pttSubReset = Duration(milliseconds: 2600);

  /// Chargement simulé d'un message en démo (avant le début de la « lecture »),
  /// le temps d'afficher le spinner. En natif, remplacé par le buffering réel.
  static const loading = Duration(milliseconds: 500);

  /// Durée de lecture simulée d'un message : `max(2200, s×180)` ms (BRIEF §8.2).
  /// Remplacée par la vraie lecture audio en natif.
  static Duration playback(Duration messageDuration) =>
      Duration(milliseconds: math.max(2200, messageDuration.inSeconds * 180));
}
