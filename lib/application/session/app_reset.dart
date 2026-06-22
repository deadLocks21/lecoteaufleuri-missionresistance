import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/radio/heard_store.dart';
import '../../infrastructure/scenario/cached_scenario.dart';
import '../../infrastructure/scenario/disk_progress_store.dart';
import '../services/emission_service.dart';
import '../services/inbox_service.dart';
import '../services/scenario_service.dart';
import '../services/tracking_service.dart';
import 'session_controller.dart';

/// Réinitialise entièrement le poste (fin de scénario).
///
/// Remet l'app dans l'état d'une installation neuve :
/// 1. **arrête le job de premier plan** (suivi GPS) et son isolate ;
/// 2. **efface toutes les données persistées** — session mémorisée (via
///    [SessionController.signOut]), progression et scénario en cache, toutes
///    équipes confondues ;
/// 3. **remet à zéro l'état mémoire** des providers scopés à la session ;
/// 4. **reverrouille** : l'écran de saisie du code redevient la racine (le
///    reverrouillage est observé par [TrackingService], 2ᵉ filet d'arrêt du
///    suivi).
class AppReset {
  AppReset(this._ref);

  final Ref _ref;

  Future<void> run() async {
    // 1. Arrêt explicite du job de premier plan (suivi GPS) avant tout le reste.
    await _ref
        .read(trackingServiceProvider.notifier)
        .stop(TrackingStopReason.manual);

    // 2. Efface la progression et le scénario mis en cache (toutes équipes).
    await DiskProgressStore.clearAll();
    await CachedScenario.clearAll();
    await HeardStore.clearAll();

    // 3. Déconnecte : efface la session mémorisée et reverrouille (→ écran de
    //    code). signOut bascule aussi le suivi en `stopped` via son écouteur.
    await _ref.read(sessionControllerProvider.notifier).signOut();

    // 4. Repart d'un état mémoire neuf pour les providers scopés session.
    _ref.invalidate(scenarioServiceProvider);
    _ref.invalidate(inboxServiceProvider);
    _ref.invalidate(emissionServiceProvider);
  }
}

final appResetProvider = Provider<AppReset>(AppReset.new);
