import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Titre de section pochoir avec filet laiton dégradé à droite (BRIEF §4.4
/// « .seclabel »).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.topMargin = 16});

  final String text;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, topMargin, 2, 8),
      child: Row(
        children: [
          Text(
            text,
            style: AppText.display(
              size: 12,
              color: TsfPalette.onOlive,
              letterSpacing: 1.5,
              height: 1.1,
              shadows: const [
                Shadow(color: Color(0xFF000000), offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [TsfPalette.brassDark, Color(0x006F5A2A)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
