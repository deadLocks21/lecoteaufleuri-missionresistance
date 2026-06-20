import 'package:flutter/widgets.dart';

/// Familles de polices embarquées (BRIEF §4.2).
abstract final class AppFonts {
  /// Titres pochoir, libellés de boutons, « INDICE X », équipe.
  static const display = 'Black Ops One';

  /// Textes courants, légendes, compteurs (500 / 600 / 700).
  static const body = 'Saira Condensed';

  /// Bandeau LCD, indices, saisie du code (machine à écrire).
  static const mono = 'Special Elite';
}

/// Fabriques de styles typographiques. Les valeurs exactes (taille, interlettrage,
/// couleur) sont passées à l'usage, au plus près de la spec.
abstract final class AppText {
  static TextStyle display({
    required double size,
    Color? color,
    double letterSpacing = 0,
    double height = 1.1,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0,
    double height = 1.2,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    required double size,
    Color? color,
    double letterSpacing = 0,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
