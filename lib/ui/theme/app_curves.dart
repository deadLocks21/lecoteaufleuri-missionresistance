import 'package:flutter/animation.dart';

/// Courbes d'easing du prototype (design-tokens `easing`).
abstract final class AppCurves {
  /// `cubic-bezier(.4,.8,.3,1)` — flip des cartes-indices.
  static const standard = Cubic(0.4, 0.8, 0.3, 1);

  /// `cubic-bezier(.4,1.3,.5,1)` — glissement (rebond) de l'interrupteur.
  static const spring = Cubic(0.4, 1.3, 0.5, 1);
}
