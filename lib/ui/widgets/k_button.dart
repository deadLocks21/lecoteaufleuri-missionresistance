import 'package:flutter/widgets.dart';

import '../theme/app_text_styles.dart';
import 'pressable.dart';

/// Variantes de touche (BRIEF §6.3).
enum KButtonVariant { olive, brass }

/// Touche bakélite « .kbtn » : olive (défaut) ou laiton (action principale).
/// Enfoncement `translateY(+4px)` au pressé.
class KButton extends StatelessWidget {
  const KButton(
    this.label, {
    super.key,
    this.onTap,
    this.variant = KButtonVariant.olive,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onTap;
  final KButtonVariant variant;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final brass = variant == KButtonVariant.brass;
    final textColor = brass ? const Color(0xFF241A07) : const Color(0xFF10210F);
    final baseShadow = brass ? const Color(0xFF5A4720) : const Color(0xFF3C4622);

    return Pressable(
      onTap: onTap,
      builder: (pressed) {
        return Transform.translate(
          offset: Offset(0, pressed ? 4 : 0),
          child: Container(
            width: fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: RadialGradient(
                center: const Alignment(0, -0.76),
                radius: 1.3,
                colors: brass
                    ? const [
                        Color(0xFFE6CF8F),
                        Color(0xFFB39750),
                        Color(0xFF7D6735),
                      ]
                    : const [
                        Color(0xFFC7D0A0),
                        Color(0xFF8C9B5F),
                        Color(0xFF5C6A35),
                      ],
                stops: const [0, 0.55, 1],
              ),
              boxShadow: pressed
                  ? [BoxShadow(color: baseShadow, offset: const Offset(0, 1))]
                  : [
                      BoxShadow(color: baseShadow, offset: const Offset(0, 4)),
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.4),
                        offset: const Offset(0, 7),
                        blurRadius: 10,
                      ),
                    ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.display(
                size: 12,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
