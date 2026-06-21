import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/config/app_config.dart';
import '../domain/entities/team.dart';
import '../domain/ports/auth_port.dart';
import '../domain/ports/dialer_port.dart';
import '../domain/ports/emission_port.dart';
import '../domain/ports/inbox_port.dart';
import '../domain/ports/session_store.dart';
import 'auth/http_auth.dart';
import 'dialer/url_launcher_dialer.dart';
import 'http/api_config.dart';
import 'memory/in_memory_auth.dart';
import 'memory/in_memory_inbox.dart';
import 'mic/mic_emission.dart';
import 'persistence/shared_prefs_session_store.dart';

/// Câblage **ports → adapters** (inversion de dépendances, ARCHITECTURE §6.5).
///
/// Les services de l'Application dépendent de ces providers de *ports*, jamais
/// d'une implémentation concrète. En l'absence de backend, on branche les
/// jumeaux `InMemory*` ; le passage au réseau ne touchera que ce fichier
/// (remplacer l'adapter, ou surcharger le provider via `ProviderScope`).

/// Tant qu'il n'y a pas de backend, on sert les jumeaux en mémoire.
const bool kUseFakes = true;

final configProvider = Provider<TsfConfig>((ref) => TsfConfig.demo);

/// Équipe de démo synthétisée depuis la config (le jumeau scénario l'ignore).
final demoTeamProvider = Provider<Team>((ref) {
  final config = ref.watch(configProvider);
  return Team(
    id: 'renards',
    name: config.teamName,
    channel: config.teamChannel,
  );
});

/// Résolution du code → équipe. Backend configuré ([kApiBaseUrl] non vide) →
/// login réseau ([HttpAuth]) ; sinon jumeau de démo (`6450` → `LES RENARDS`).
final authPortProvider = Provider<AuthPort>((ref) {
  final config = ref.watch(configProvider);
  if (kApiBaseUrl.isEmpty) {
    return InMemoryAuth(
      code: config.accessCode,
      team: ref.watch(demoTeamProvider),
    );
  }
  return HttpAuth(baseUrl: kApiBaseUrl, channel: config.teamChannel);
});

/// Persistance locale de session (reconnexion auto sans redemander le code).
/// Surchargée en test par `InMemorySessionStore`.
final sessionStoreProvider =
    Provider<SessionStore>((ref) => SharedPrefsSessionStore());

/// Le VU-mètre suit le micro réel ; passe à `InMemoryEmission()` pour revenir
/// au jumeau (niveaux aléatoires, sans permission micro).
final emissionPortProvider = Provider<EmissionPort>((ref) => MicEmission());

final inboxPortProvider = Provider<InboxPort>((ref) => InMemoryInbox());

// `scenarioPortProvider` et `progressStoreProvider` sont définis dans
// `application/services/scenario_service.dart` : ils dépendent de
// `currentTeamProvider` (couche application), qu'on évite d'importer ici pour
// ne pas créer de cycle `di` ↔ `session_controller`.

final dialerPortProvider = Provider<DialerPort>((ref) {
  final config = ref.watch(configProvider);
  return UrlLauncherDialer(config.telQg);
});
