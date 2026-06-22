import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/config/app_config.dart';
import '../domain/entities/team.dart';
import '../domain/ports/auth_port.dart';
import '../domain/ports/dialer_port.dart';
import '../domain/ports/emission_port.dart';
import '../domain/ports/player_port.dart';
import '../domain/ports/session_store.dart';
import 'audio/just_audio_player.dart';
import 'auth/http_auth.dart';
import 'dialer/url_launcher_dialer.dart';
import 'http/api_config.dart';
import 'memory/in_memory_auth.dart';
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

/// Le VU-mètre suit le micro réel et l'émission est enregistrée dans un fichier
/// temporaire ; passe à `InMemoryEmission()` pour revenir au jumeau (niveaux
/// aléatoires, sans capture ni permission micro).
final emissionPortProvider = Provider<EmissionPort>((ref) => MicEmission());

/// Lecteur audio des messages reçus (réception backend). Pas de jumeau requis :
/// en démo, les messages n'ont pas d'`audioUrl` et la lecture est simulée.
final playerPortProvider = Provider<PlayerPort>((ref) {
  final player = JustAudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

// Providers *scopés à l'équipe* définis côté Application (ils dépendent de
// `currentTeamProvider`, qu'on évite d'importer ici pour ne pas créer de cycle
// `di` ↔ `session_controller`) :
//   • `scenarioPortProvider` / `progressStoreProvider` → scenario_service.dart
//   • `inboxPortProvider`                              → inbox_service.dart
//   • `outboxPortProvider`                             → emission_service.dart

final dialerPortProvider = Provider<DialerPort>((ref) {
  final config = ref.watch(configProvider);
  return UrlLauncherDialer(config.telQg);
});
