import 'package:flutter/material.dart';

import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/resistance_logo.dart';

/// Écran affiché entre deux parties : **en attente** (aucune partie lancée) ou
/// **terminée** (le QG a arrêté la partie). Le poste sonde le serveur en fond et
/// bascule automatiquement dans le jeu dès qu'une partie (re)démarre.
class PartieStatusScreen extends StatelessWidget {
  const PartieStatusScreen.waiting({super.key})
      : _title = Strings.partieWaitingTitle,
        _body = Strings.partieWaitingBody;

  const PartieStatusScreen.ended({super.key})
      : _title = Strings.partieEndedTitle,
        _body = Strings.partieEndedBody;

  final String _title;
  final String _body;

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
                _title.toUpperCase(),
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
                _body,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TsfPalette.brass,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
