import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/session/session_controller.dart';
import '../ui/features/lock/lock_screen.dart';
import '../ui/features/shell/radio_shell.dart';
import '../ui/strings.dart';
import '../ui/theme/app_colors.dart';

/// Racine de l'app : `MaterialApp` + redirection selon l'état de session
/// (verrouillé → écran de code ; déverrouillé → shell à deux onglets).
class MissionResistanceApp extends StatelessWidget {
  const MissionResistanceApp({super.key});

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
