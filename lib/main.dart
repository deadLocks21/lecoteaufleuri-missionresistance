import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mission_resistance/ui/theme/app_colors.dart';
import 'package:mission_resistance/ui/widgets/resistance_logo.dart';

void main() {
  runApp(const ProviderScope(child: MissionResistanceApp()));
}

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
      home: const _BrandSplashPage(),
    );
  }
}

/// Écran d'accueil provisoire : montre le logo le temps de mettre en place le
/// poste (écran de code, émission, réception, scénario — cf. `design/SPEC.md`).
class _BrandSplashPage extends StatelessWidget {
  const _BrandSplashPage();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ResistanceLogo(size: 132),
            const SizedBox(height: 24),
            Text(
              'Mission Résistance',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Poste radio TSF · réseau de la Résistance',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
