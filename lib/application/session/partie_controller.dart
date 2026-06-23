import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/partie.dart';
import '../../infrastructure/di.dart';
import '../config/timings.dart';
import 'session_controller.dart';

/// État de **partie** côté poste (BRIEF — la régie démarre/arrête une partie).
sealed class PartieState {
  const PartieState();
}

/// Avant la première résolution (juste après l'unlock).
class PartieUnknown extends PartieState {
  const PartieUnknown();
}

/// Aucune partie active : le poste affiche « en attente de partie ».
class PartieWaiting extends PartieState {
  const PartieWaiting();
}

/// Partie en cours : le jeu est actif (GPS, progression, radio scopés à `partie`).
class PartiePlaying extends PartieState {
  const PartiePlaying(this.partie);
  final Partie partie;
}

/// La partie qu'on jouait est terminée : le poste affiche « partie terminée ».
class PartieOver extends PartieState {
  const PartieOver(this.previous);
  final Partie previous;
}

/// Source de vérité de l'état de partie du poste. Amorcé depuis la session
/// mémorisée (en-tête `X-Partie-Id` disponible dès les premiers appels), puis
/// **sondé** (`GET /sessions/:team/partie`, ~10 s) pour détecter le début et la
/// fin d'une partie. Pilote l'UI (en attente / en jeu / terminée), l'en-tête des
/// adapters réseau ([currentPartieIdProvider]) et le démarrage du suivi GPS.
class PartieController extends Notifier<PartieState> {
  Timer? _poll;

  @override
  PartieState build() {
    ref.onDispose(_stopPolling);
    ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
      if (next is Unlocked) {
        unawaited(_start());
      } else if (next is! Unlocking) {
        // Verrouillage / déconnexion : on arrête de sonder et on oublie l'état.
        _stopPolling();
        state = const PartieUnknown();
      }
    });
    if (ref.read(sessionControllerProvider) is Unlocked) {
      Future.microtask(_start);
    }
    return const PartieUnknown();
  }

  Future<void> _start() async {
    // Amorce depuis la dernière partie connue (évite un flash « ardoise vierge »
    // à la reconnexion : l'en-tête part juste avant que le poll ne confirme).
    try {
      final stored = await ref.read(sessionStoreProvider).load();
      final seed = stored?.partieId;
      if (seed != null && state is! PartiePlaying) {
        state = PartiePlaying(Partie(id: seed));
      }
    } catch (_) {
      // Lecture impossible : on s'en remet au poll ci-dessous.
    }
    await refresh();
    _poll ??= Timer.periodic(Timings.partiePoll, (_) => unawaited(refresh()));
  }

  /// Lit l'état serveur et transitionne. Un **aléa réseau** conserve l'état
  /// courant (on ne bascule « terminée » que sur un `null` franc du serveur).
  Future<void> refresh() async {
    final team = ref.read(currentTeamProvider);
    if (team == null) return;

    final Partie? partie;
    try {
      partie = await ref.read(partiePortProvider).current(team);
    } catch (_) {
      return; // réseau indisponible : on garde l'état, on réessaiera
    }

    if (partie != null) {
      // (Ré)ouverture ou nouvelle partie : on (re)joue (ardoise vierge si l'id
      // a changé — les providers scopés à la partie se reconstruisent).
      state = PartiePlaying(partie);
    } else {
      // Pas de partie côté serveur. On distingue trois cas :
      // - on jouait → la partie vient de se terminer (écran de fin) ;
      // - on affichait déjà la fin → **terminal**, on y reste (sinon le poll
      //   suivant retomberait en « en attente » et masquerait l'écran de fin) ;
      // - sinon → aucune partie n'a encore démarré (« en attente »).
      state = switch (state) {
        PartiePlaying(:final partie) => PartieOver(partie),
        PartieOver() => state,
        _ => const PartieWaiting(),
      };
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }
}

final partieControllerProvider =
    NotifierProvider<PartieController, PartieState>(PartieController.new);

/// Id de partie courant pour l'en-tête `X-Partie-Id` (null hors « en jeu »).
final currentPartieIdProvider = Provider<String?>((ref) {
  final s = ref.watch(partieControllerProvider);
  return s is PartiePlaying ? s.partie.id : null;
});
