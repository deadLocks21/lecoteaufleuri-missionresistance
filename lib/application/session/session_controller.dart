import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/team.dart';
import '../../domain/exceptions/domain_exception.dart';
import '../../domain/value_objects/access_code.dart';
import '../../infrastructure/di.dart';
import '../config/timings.dart';

/// État scellé d'accès à l'app (BRIEF §5, §7 / ARCHITECTURE §5.2).
sealed class SessionState {
  const SessionState();
}

/// Verrouillé : l'app est masquée. [invalidCode] déclenche le shake côté UI.
class Locked extends SessionState {
  const Locked({this.invalidCode = false});
  final bool invalidCode;
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
  SessionState build() => const Locked();

  /// Valide une saisie. Vide → no-op (comme le prototype). Mauvais code →
  /// `Locked(invalidCode)`. Bon code → `Unlocking` puis `Unlocked` après 750 ms.
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
      state = Unlocking(team);
      await Future<void>.delayed(Timings.unlock);
      if (state is Unlocking) {
        state = Unlocked(team);
      }
    } on InvalidCodeException {
      state = const Locked(invalidCode: true);
    }
  }

  /// Reverrouille le poste (revient à l'écran de code).
  void lock() => state = const Locked();
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
