import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/team.dart';
import '../../domain/exceptions/domain_exception.dart';
import '../../domain/value_objects/access_code.dart';
import '../../domain/value_objects/stored_session.dart';
import '../../infrastructure/di.dart';
import '../config/timings.dart';

/// Motif d'un état verrouillé, pour l'indice affiché sous le champ de code.
enum LockError {
  /// En attente de saisie (premier affichage).
  none,

  /// Code refusé par le backend → shake + halo rouge.
  invalidCode,

  /// Backend injoignable → indice « réseau » (pas de shake : pas la faute du joueur).
  network,
}

/// État scellé d'accès à l'app (BRIEF §5, §7 / ARCHITECTURE §5.2).
sealed class SessionState {
  const SessionState();
}

/// Au lancement : tentative de reconnexion automatique depuis la session
/// mémorisée (splash bref ; on n'affiche pas l'écran de code par à-coups).
class Restoring extends SessionState {
  const Restoring();
}

/// Verrouillé : l'app est masquée. [error] pilote l'indice (shake si `invalidCode`).
class Locked extends SessionState {
  const Locked({this.error = LockError.none});
  final LockError error;
}

/// Code accepté : transition de 750 ms (plaque → équipe, hint vert).
class Unlocking extends SessionState {
  const Unlocking(this.team);
  final Team team;
}

/// Déverrouillé : on accède au shell à deux onglets.
class Unlocked extends SessionState {
  const Unlocked(this.team);
  final Team team;
}

/// Pilote l'écran de verrouillage → app (cf. ARCHITECTURE §8).
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Restauration **best-effort** et hors-ligne : si une session est mémorisée,
    // on déverrouille directement sans appel réseau (« on ne redemande pas »).
    Future.microtask(_restore);
    return const Restoring();
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(sessionStoreProvider).load();
      if (stored != null) {
        state = Unlocked(_teamFrom(stored));
        return;
      }
    } catch (_) {
      // Lecture impossible / corrompue : on retombe sur l'écran de code.
    }
    state = const Locked();
  }

  /// Valide une saisie. Vide → no-op (comme le prototype). Mauvais code → shake.
  /// Réseau KO → indice réseau. Bon code → mémorise puis `Unlocking`→`Unlocked`.
  Future<void> submit(String raw) async {
    if (AccessCode.isBlank(raw)) return;

    final AccessCode code;
    try {
      code = AccessCode(raw);
    } on EmptyCodeException {
      return;
    }

    try {
      final team = await ref.read(authPortProvider).unlock(code);
      // Mémorise code + identité d'équipe pour la reconnexion automatique.
      await ref.read(sessionStoreProvider).save(
            StoredSession(code: code.value, teamId: team.id, teamName: team.name),
          );
      state = Unlocking(team);
      await Future<void>.delayed(Timings.unlock);
      if (state is Unlocking) {
        state = Unlocked(team);
      }
    } on InvalidCodeException {
      state = const Locked(error: LockError.invalidCode);
    } on NetworkException {
      state = const Locked(error: LockError.network);
    }
  }

  /// Déconnecte le poste : efface la session mémorisée et reverrouille.
  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).clear();
    state = const Locked();
  }

  /// Reverrouille le poste sans effacer la session (rare ; reconnexion au boot).
  void lock() => state = const Locked();

  Team _teamFrom(StoredSession s) => Team(
        id: s.teamId,
        name: s.teamName,
        // Fréquence décorative, constante pour toutes les équipes.
        channel: ref.read(configProvider).teamChannel,
      );
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Équipe authentifiée courante (`null` tant qu'on n'est pas déverrouillé).
/// Source unique pour le suivi GPS (clé des positions = `team.id`).
final currentTeamProvider = Provider<Team?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return switch (session) {
    Unlocking(:final team) => team,
    Unlocked(:final team) => team,
    _ => null,
  };
});
