import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/session/session_controller.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/resistance_logo.dart';

/// Écran **d'attente** : aucune partie n'a encore été lancée par le QG. Le poste
/// sonde le serveur en fond et bascule automatiquement dans le jeu dès qu'une
/// partie démarre — d'où le spinner qui tourne.
class PartieStatusScreen extends StatelessWidget {
  const PartieStatusScreen.waiting({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PartieStatusLayout(
      title: Strings.partieWaitingTitle,
      body: Strings.partieWaitingBody,
      trailing: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: TsfPalette.brass,
        ),
      ),
    );
  }
}

/// Écran **de fin** : le QG a mis fin à la partie (ou le poste se reconnecte sur
/// une partie déjà terminée). Terminal — pas de retour automatique en jeu : le
/// joueur lit le message puis revient à l'écran de connexion via le bouton, ce
/// qui déconnecte le poste (un nouveau code pourra être saisi).
class PartieEndedScreen extends ConsumerWidget {
  const PartieEndedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PartieStatusLayout(
      title: Strings.partieEndedTitle,
      body: Strings.partieEndedBody,
      trailing: OutlinedButton(
        onPressed: () =>
            ref.read(sessionControllerProvider.notifier).signOut(),
        style: OutlinedButton.styleFrom(
          foregroundColor: TsfPalette.brass,
          side: const BorderSide(color: TsfPalette.brass),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: const Text(
          Strings.partieEndedAction,
          style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Mise en page partagée des écrans de statut de partie (logo + titre + corps +
/// élément final, spinner ou bouton selon l'état).
class _PartieStatusLayout extends StatelessWidget {
  const _PartieStatusLayout({
    required this.title,
    required this.body,
    required this.trailing,
  });

  final String title;
  final String body;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: TsfPalette.appBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ResistanceLogo(size: 84),
              const SizedBox(height: 28),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TsfPalette.brass,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 28),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
