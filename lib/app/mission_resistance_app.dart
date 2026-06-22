import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/inbox_service.dart';
import '../application/services/tracking_service.dart';
import '../application/session/partie_controller.dart';
import '../application/session/session_controller.dart';
import '../infrastructure/telemetry/telemetry_providers.dart';
import '../ui/features/lock/lock_screen.dart';
import '../ui/features/partie/partie_status_screen.dart';
import '../ui/features/shell/radio_shell.dart';
import '../ui/strings.dart';
import '../ui/theme/app_colors.dart';

/// Racine de l'app : `MaterialApp` + redirection selon l'état de session
/// (verrouillé → écran de code ; déverrouillé → shell à deux onglets).
///
/// Observe le cycle de vie pour journaliser resume/pause et *vider* le tampon
/// du logger avant que l'OS ne suspende le process (sinon les derniers logs
/// bufferisés par `SignozLogger` seraient perdus).
class MissionResistanceApp extends ConsumerStatefulWidget {
  const MissionResistanceApp({super.key});

  @override
  ConsumerState<MissionResistanceApp> createState() =>
      _MissionResistanceAppState();
}

class _MissionResistanceAppState extends ConsumerState<MissionResistanceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Instancie le contrôleur de partie **et** le service de suivi dès le départ
    // pour que leurs écoutes (poll de partie ; démarrage du GPS quand une partie
    // est en cours) soient branchées avant l'unlock.
    ref.read(partieControllerProvider.notifier);
    ref.read(trackingServiceProvider.notifier);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final logger = ref.read(loggerProvider);
    final tracking = ref.read(trackingServiceProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        logger.info('app.resumed');
        // Liveness : relance le suivi si un OEM a tué le service en fond.
        tracking.ensureAlive();
        // Rattrape les messages arrivés app fermée : le push de l'isolate de
        // fond ne parvient pas à l'UI suspendue, on recharge donc le backlog.
        if (ref.read(sessionControllerProvider) is Unlocked) {
          ref.read(inboxServiceProvider.notifier).refresh();
        }
      case AppLifecycleState.paused:
        // Flush des logs bufferisés avant suspension. Les positions, elles,
        // sont gérées par l'isolate d'arrière-plan, qui continue de tourner.
        logger.info('app.paused');
        logger.flush();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mission Résistance',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.buildLightTheme(),
      darkTheme: AppThemeData.buildDarkTheme(),
      themeMode: ThemeMode.dark,
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `Restoring` (reconnexion auto) → splash ; `Unlocked` → selon la **partie**
    // (en jeu → shell ; en attente / terminée → écran de statut) ; sinon code.
    // La transition de déverrouillage (`Unlocking`) reste sur l'écran de code.
    final session = ref.watch(sessionControllerProvider);
    final Widget child = switch (session) {
      Unlocked() => _unlockedChild(ref),
      Restoring() => const _StartupSplash(key: ValueKey('splash')),
      _ => const LockScreen(key: ValueKey('lock')),
    };

    return Scaffold(
      backgroundColor: TsfPalette.appBg,
      body: Semantics(
        label: Strings.a11yTitle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: child,
        ),
      ),
    );
  }

  /// Déverrouillé : l'accès au jeu dépend de l'état de **partie** (la régie la
  /// démarre/arrête). En jeu → shell ; sinon écran de statut (en attente /
  /// terminée), le poste sondant le serveur en fond pour (re)basculer.
  Widget _unlockedChild(WidgetRef ref) {
    final partie = ref.watch(partieControllerProvider);
    return switch (partie) {
      PartiePlaying() => const RadioShell(key: ValueKey('shell')),
      PartieOver() => const PartieStatusScreen.ended(key: ValueKey('partie-ended')),
      _ => const PartieStatusScreen.waiting(key: ValueKey('partie-waiting')),
    };
  }
}

/// Splash bref pendant la reconnexion automatique (lecture des shared
/// preferences) — évite un clignotement de l'écran de code au lancement.
class _StartupSplash extends StatelessWidget {
  const _StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: TsfPalette.appBg,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: TsfPalette.brass,
          ),
        ),
      ),
    );
  }
}
