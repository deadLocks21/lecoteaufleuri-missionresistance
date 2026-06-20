import 'package:flutter/widgets.dart';

import '../../application/config/timings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Bandeau LCD vert (BRIEF §6.2) : une ligne machine à écrire + curseur `▮`
/// clignotant (1 s). Le texte (défaut ou transitoire) est résolu en amont.
class LcdTicker extends StatefulWidget {
  const LcdTicker({super.key, required this.text});

  final String text;

  @override
  State<LcdTicker> createState() => _LcdTickerState();
}

class _LcdTickerState extends State<LcdTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: Timings.blink,
  )..repeat();

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppText.mono(
      size: 11.5,
      color: TsfPalette.lcdText,
      letterSpacing: 0.3,
      height: 1.2,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 14),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: TsfPalette.lcdBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF000000)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF285A14).withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: style,
            ),
          ),
          FadeTransition(
            opacity: _CursorOpacity(_blink),
            child: Text('▮', style: style),
          ),
        ],
      ),
    );
  }
}

/// Opacité en créneau (steps) : visible la moitié du cycle, cachée l'autre.
class _CursorOpacity extends Animation<double>
    with AnimationWithParentMixin<double> {
  _CursorOpacity(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value < 0.5 ? 1 : 0;
}
