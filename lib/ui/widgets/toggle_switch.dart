import 'package:flutter/widgets.dart';

import '../state/view_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_curves.dart';
import '../theme/app_text_styles.dart';
import '../../application/config/timings.dart';
import 'app_icons.dart';

/// Barre de navigation à interrupteur à bascule (BRIEF §5.1, §4.4 « .navflip »).
/// Libellé actif ambre lumineux ; manette qui glisse (0,2 s, rebond).
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({super.key, required this.view, required this.onChanged});

  final ShellTab view;
  final ValueChanged<ShellTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF1F2117)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3F4330), Color(0xFF2A2C20)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavLabel(
            label: 'Radio',
            icon: AppIcons.radio,
            active: view == ShellTab.radio,
            onTap: () => onChanged(ShellTab.radio),
          ),
          const SizedBox(width: 14),
          _FlipSwitch(
            atEnd: view == ShellTab.mission,
            onTap: () => onChanged(
              view == ShellTab.radio ? ShellTab.mission : ShellTab.radio,
            ),
          ),
          const SizedBox(width: 14),
          _NavLabel(
            label: 'Carnet',
            icon: AppIcons.carnet,
            active: view == ShellTab.mission,
            onTap: () => onChanged(ShellTab.mission),
          ),
        ],
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Widget Function(double size, Color color) icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? TsfPalette.amber : const Color(0xFF8B8A72);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(17, color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.display(
              size: 12,
              color: color,
              letterSpacing: 0.5,
              height: 1.1,
              shadows: active
                  ? [
                      Shadow(
                        color: TsfPalette.amberGlow.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipSwitch extends StatelessWidget {
  const _FlipSwitch({required this.atEnd, required this.onTap});

  final bool atEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 74,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF000000)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF15160F), Color(0xFF070806)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.8),
              offset: const Offset(0, 2),
              blurRadius: 5,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Timings.toggle,
              curve: AppCurves.spring,
              top: 4,
              left: atEnd ? 40 : 4,
              child: Container(
                width: 30,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const RadialGradient(
                    center: Alignment(-0.2, -0.4),
                    colors: [
                      Color(0xFFD9D9CF),
                      Color(0xFF6A6A5F),
                      Color(0xFF3A3A32),
                    ],
                    stops: [0, 0.7, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.6),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
