import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/config/app_config.dart';
import '../domain/entities/team.dart';
import '../domain/ports/auth_port.dart';
import '../domain/ports/dialer_port.dart';
import '../domain/ports/emission_port.dart';
import '../domain/ports/inbox_port.dart';
import '../domain/ports/progress_store.dart';
import '../domain/ports/scenario_port.dart';
import 'dialer/url_launcher_dialer.dart';
import 'memory/in_memory_auth.dart';
import 'memory/in_memory_emission.dart';
import 'memory/in_memory_inbox.dart';
import 'memory/in_memory_progress_store.dart';
import 'memory/in_memory_scenario.dart';

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

final authPortProvider = Provider<AuthPort>((ref) {
  final config = ref.watch(configProvider);
  return InMemoryAuth(
    code: config.accessCode,
    team: ref.watch(demoTeamProvider),
  );
});

final emissionPortProvider =
    Provider<EmissionPort>((ref) => InMemoryEmission());

final inboxPortProvider = Provider<InboxPort>((ref) => InMemoryInbox());

final scenarioPortProvider =
    Provider<ScenarioPort>((ref) => InMemoryScenario());

final progressStoreProvider =
    Provider<ProgressStore>((ref) => InMemoryProgressStore());

final dialerPortProvider = Provider<DialerPort>((ref) {
  final config = ref.watch(configProvider);
  return UrlLauncherDialer(config.telQg);
});
