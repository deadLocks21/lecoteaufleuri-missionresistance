import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/session/app_reset.dart';
import '../../state/ticker_controller.dart';
import '../../state/view_controller.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/k_button.dart';

/// Écran de fin de scénario (toutes les missions accomplies, ARCHITECTURE §11).
///
/// Deux issues : **réinitialiser le poste** (arrêt du suivi, données effacées,
/// retour à l'écran de code) ou **rester dans la partie** (simple fermeture). Il
/// est ré-affiché à chaque nouvel appui sur « Mission accomplie » de la dernière
/// mission. Tap hors de la boîte = rester.
Future<void> showScenarioCompleteModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC080905),
    builder: (_) => const _ScenarioCompleteDialog(),
  );
}

class _ScenarioCompleteDialog extends ConsumerWidget {
  const _ScenarioCompleteDialog();

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    // État de présentation (onglet courant, bandeau transitoire) remis à zéro
    // côté UI…
    ref.invalidate(viewControllerProvider);
    ref.invalidate(tickerControllerProvider);
    // …puis l'état applicatif : suivi GPS arrêté, caches effacés, session close
    // (→ l'écran de code redevient la racine, sous cette boîte).
    await ref.read(appResetProvider).run();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TsfPalette.brassDark, width: 2),
              gradient: const RadialGradient(
                center: Alignment(0, -0.85),
                radius: 1.2,
                colors: [
                  TsfPalette.oliveLight,
                  TsfPalette.olivePanel,
                  TsfPalette.oliveDark,
                ],
                stops: [0, 0.5, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.6),
                  offset: const Offset(0, 16),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Medallion(),
                const SizedBox(height: 18),
                Text(
                  Strings.scenarioCompleteTitle,
                  textAlign: TextAlign.center,
                  style: AppText.display(
                    size: 24,
                    color: TsfPalette.cream,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  Strings.scenarioCompleteHeadline,
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: TsfPalette.amber,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  Strings.scenarioCompleteBody,
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                    size: 13,
                    color: const Color(0xFFCDBB88),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                KButton(
                  Strings.scenarioCompleteReset,
                  variant: KButtonVariant.brass,
                  fullWidth: true,
                  onTap: () => _reset(context, ref),
                ),
                const SizedBox(height: 10),
                KButton(
                  Strings.scenarioCompleteStay,
                  fullWidth: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Médaillon « ✓ » en laiton — écho agrandi du numéro d'étape terminée du
/// carnet, pour signer la fin du scénario.
class _Medallion extends StatelessWidget {
  const _Medallion();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [
            TsfPalette.brassLight,
            TsfPalette.brass,
            TsfPalette.brassDark,
          ],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: TsfPalette.brass.withValues(alpha: 0.45),
            blurRadius: 20,
          ),
        ],
      ),
      child: Text(
        '✓',
        style: AppText.display(
          size: 30,
          color: const Color(0xFF1A140A),
          height: 1,
        ),
      ),
    );
  }
}
