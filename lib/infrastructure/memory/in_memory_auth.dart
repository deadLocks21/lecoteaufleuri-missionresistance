import '../../domain/entities/team.dart';
import '../../domain/exceptions/domain_exception.dart';
import '../../domain/ports/auth_port.dart';
import '../../domain/value_objects/access_code.dart';
import 'in_memory_partie.dart';

/// Jumeau InMemory de [AuthPort] : accepte le code de démo `6450` → `LES RENARDS`
/// (ARCHITECTURE §8). En natif, le code mappera vers l'équipe via le backend.
/// La démo a toujours une partie active ([InMemoryPartie.demo]) → le poste joue
/// immédiatement.
class InMemoryAuth implements AuthPort {
  InMemoryAuth({required String code, required Team team})
      : _expected = AccessCode(code),
        _team = team;

  final AccessCode _expected;
  final Team _team;

  @override
  Future<LoginResult> unlock(AccessCode code) async {
    if (code == _expected) {
      return LoginResult(team: _team, partie: InMemoryPartie.demo);
    }
    throw const InvalidCodeException();
  }
}
