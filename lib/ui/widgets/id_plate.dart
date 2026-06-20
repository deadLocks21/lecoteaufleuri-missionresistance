import 'package:flutter/widgets.dart';

import '../strings.dart';
import '../theme/app_text_styles.dart';

/// Plaque d'identité laiton rivetée (BRIEF §6.1). Affiche le modèle et le nom
/// d'équipe (`VERROUILLÉ` tant que le poste n'est pas déverrouillé).
class IdPlate extends StatelessWidget {
  const IdPlate({super.key, required this.team});

  /// Texte de la ligne équipe (`VERROUILLÉ` ou nom d'équipe).
  final String team;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6F5A2A)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDB877), Color(0xFF9C8244), Color(0xFF7D6735)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.5),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          const _Rivet(),
          Expanded(
            child: Column(
              children: [
                Text(
                  Strings.model.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFF33270F),
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
                Text(
                  team,
                  textAlign: TextAlign.center,
                  style: AppText.display(
                    size: 16,
                    color: const Color(0xFF241A07),
                    letterSpacing: 1,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.35),
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _Rivet(),
        ],
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  const _Rivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFFFFF), Color(0xFF7D6735)],
        ),
      ),
    );
  }
}
