import 'package:flutter/material.dart';

import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/k_button.dart';

/// Modal de confirmation avant déchiffrement (BRIEF §9.4). Tap hors de la boîte
/// = annuler. Renvoie `true` si l'utilisateur confirme.
Future<bool> showDecipherModal(BuildContext context, int number) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB8080905),
    builder: (context) => _ConfirmDialog(number: number),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TsfPalette.oliveEdge, width: 2),
              gradient: const RadialGradient(
                center: Alignment(0, -1),
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
                Text(
                  Strings.modalTitle,
                  textAlign: TextAlign.center,
                  style: AppText.display(
                    size: 15,
                    color: TsfPalette.cream,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Strings.modalMessage(number),
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                    size: 13,
                    color: const Color(0xFFCDBB88),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: KButton(
                        Strings.cancel,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KButton(
                        Strings.decipher,
                        variant: KButtonVariant.brass,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
