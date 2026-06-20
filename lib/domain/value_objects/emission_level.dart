import 'dart:math' as math;

/// Niveau d'émission du VU-mètre, sur l'échelle 0–10.
///
/// Porte la règle de géométrie de l'instrument (BRIEF §8.1.a) :
/// `angle(°) = valeur*10 − 50` (0 → −50°, 10 → +50°).
class EmissionLevel {
  const EmissionLevel(this.value)
      : assert(value >= 0 && value <= 10, 'niveau VU hors échelle 0–10');

  /// Position de repos de l'aiguille : −46° (cf. prototype `setVU(-46)`).
  static const EmissionLevel rest = EmissionLevel(0.4);

  /// Valeur sur l'échelle 0–10.
  final double value;

  /// Angle de l'aiguille en degrés (−50°..+50°).
  double get angleDegrees => value * 10 - 50;

  /// Niveau aléatoire d'émission (jumeau de démo) : `(0.35 + rnd*0.6) * 10`,
  /// soit 3,5–9,5 sur l'échelle. L'amplitude réelle du micro remplacera ceci
  /// en natif.
  factory EmissionLevel.random(math.Random rng) =>
      EmissionLevel((0.35 + rng.nextDouble() * 0.6) * 10);

  @override
  bool operator ==(Object other) =>
      other is EmissionLevel && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
