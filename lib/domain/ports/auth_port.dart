import '../entities/team.dart';
import '../value_objects/access_code.dart';
import '../value_objects/partie.dart';

/// Résultat d'un login réussi : l'équipe résolue + la **partie active** de son
/// groupe (`null` si aucune partie n'est en cours — l'app affiche alors « en
/// attente de partie »).
class LoginResult {
  const LoginResult({required this.team, this.partie});

  final Team team;
  final Partie? partie;
}

/// Résout un code d'accès en équipe (+ partie active). Lève
/// `InvalidCodeException` si le code est invalide (cf. ARCHITECTURE §4.3).
abstract interface class AuthPort {
  Future<LoginResult> unlock(AccessCode code);
}
