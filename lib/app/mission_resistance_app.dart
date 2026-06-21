import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/services/tracking_service.dart';
import '../application/session/session_controller.dart';
import '../infrastructure/telemetry/telemetry_providers.dart';
import '../ui/features/lock/lock_screen.dart';
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
    // Instancie le service de suivi dès le départ pour que son écoute de la
    // session (démarrage au déverrouillage) soit branchée avant l'unlock.
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
    // `Restoring` (reconnexion auto) → splash ; `Unlocked` → shell ; sinon code.
    // La transition de déverrouillage (`Unlocking`) reste sur l'écran de code.
    final session = ref.watch(sessionControllerProvider);
    final Widget child = switch (session) {
      Unlocked() => const RadioShell(key: ValueKey('shell')),
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
