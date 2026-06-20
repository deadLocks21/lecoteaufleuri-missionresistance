// Exceptions métier. Toutes dérivent de [DomainException] pour que l'Application
// et l'UI puissent les distinguer des erreurs techniques (cf. ARCHITECTURE §4.3).

/// Base de toutes les erreurs du domaine.
sealed class DomainException implements Exception {
  const DomainException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Saisie de code vide (l'écran ne doit rien faire, comme le prototype).
class EmptyCodeException extends DomainException {
  const EmptyCodeException() : super('Code vide');
}

/// Code d'accès incorrect — déclenche le shake + halo rouge côté UI.
class InvalidCodeException extends DomainException {
  const InvalidCodeException() : super('CODE INCORRECT — réessayez');
}

/// Échec d'ouverture du micro / d'émission.
class EmissionException extends DomainException {
  const EmissionException([super.message = "Échec de l'émission"]);
}

/// Échec de lecture d'un message reçu.
class PlaybackException extends DomainException {
  const PlaybackException([super.message = 'Échec de la lecture']);
}
