import '../exceptions/domain_exception.dart';

/// Code d'accès du poste.
///
/// Value object auto-validé : encapsule la comparaison **insensible à la casse**
/// après `trim()` (cf. BRIEF §7 : `value.trim().toLowerCase()`). Rejette une
/// saisie vide via [EmptyCodeException].
class AccessCode {
  factory AccessCode(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const EmptyCodeException();
    }
    return AccessCode._(normalized);
  }

  const AccessCode._(this._normalized);

  final String _normalized;

  /// Valeur normalisée (à transmettre au backend ; le `toString` reste masqué).
  String get value => _normalized;

  /// `true` si l'utilisateur n'a saisi que des espaces / rien.
  static bool isBlank(String raw) => raw.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is AccessCode && other._normalized == _normalized;

  @override
  int get hashCode => _normalized.hashCode;

  @override
  String toString() => 'AccessCode(••••)';
}
