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
        // Flush pour que les logs / positions bufferisés partent avant une
        // éventuelle suspension par l'OS.
        logger.info('app.paused');
        logger.flush();
        tracking.flush();
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
    // Verrou tant que le code n'est pas validé (la transition de déverrouillage
    // reste sur l'écran de code pendant 750 ms).
    final unlocked = ref.watch(sessionControllerProvider) is Unlocked;

    return Scaffold(
      backgroundColor: TsfPalette.appBg,
      body: Semantics(
        label: Strings.a11yTitle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: unlocked
              ? const RadioShell(key: ValueKey('shell'))
              : const LockScreen(key: ValueKey('lock')),
        ),
      ),
    );
  }
}
