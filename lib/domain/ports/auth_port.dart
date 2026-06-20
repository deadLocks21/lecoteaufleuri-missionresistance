import '../entities/team.dart';
import '../value_objects/access_code.dart';

/// Résout un code d'accès en équipe. Lève `InvalidCodeException` si le code est
/// invalide (cf. ARCHITECTURE §4.3).
abstract interface class AuthPort {
  Future<Team> unlock(AccessCode code);
}
