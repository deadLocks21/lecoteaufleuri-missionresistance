import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Panneau métal vert olive plein écran (BRIEF §4.4 « .set ») : dégradé radial
/// éclairé en haut, texture rayée diagonale, vignette interne, et **4 vis** aux
/// coins (sous la safe-area). Le contenu est décalé via les safe-area insets.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({
    super.key,
    required this.child,
    this.scrollable = true,
    this.scrollController,
  });

  final Widget child;

  /// `true` pour l'app (contenu qui défile) ; `false` pour le verrouillage
  /// (contenu centré qui remplit la hauteur).
  final bool scrollable;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(14, inset.top + 26, 14, inset.bottom + 24);

    return ColoredBox(
      color: TsfPalette.bezel,
      child: Stack(
        children: [
          const Positioned.fill(child: _PanelBackground()),
          Positioned.fill(
            child: scrollable
                ? SingleChildScrollView(
                    controller: scrollController,
                    padding: padding,
                    child: child,
                  )
                : Padding(padding: padding, child: child),
          ),
          _Screw(top: inset.top + 9, left: 10),
          _Screw(top: inset.top + 9, right: 10),
          _Screw(bottom: inset.bottom + 9, left: 10),
          _Screw(bottom: inset.bottom + 9, right: 10),
        ],
      ),
    );
  }
}

class _PanelBackground extends StatelessWidget {
  const _PanelBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base : radial éclairé en haut-centre (panelLight → panel → panelDark).
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.15,
                colors: [
                  TsfPalette.oliveLight,
                  TsfPalette.olivePanel,
                  TsfPalette.oliveDark,
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
        // Texture rayée diagonale très légère.
        Positioned.fill(child: CustomPaint(painter: _TexturePainter())),
        // Vignette : assombrissement des bords (inset 0 0 70px rgba(0,0,0,.4)).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.95,
                colors: [
                  const Color(0x00000000),
                  const Color(0x00000000),
                  const Color(0x66000000),
                ],
                stops: const [0, 0.6, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final light = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.022)
      ..strokeWidth = 1;
    final dark = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    // Lignes ~115° (vers le haut-gauche), pas de 4px.
    for (double x = -size.height; x < size.width + size.height; x += 4) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.47, 0),
        light,
      );
      canvas.drawLine(
        Offset(x + 2, size.height),
        Offset(x + 2 + size.height * 0.47, 0),
        dark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vis cruciforme des coins du panneau (« .screw », 13px).
class _Screw extends StatelessWidget {
  const _Screw({this.top, this.bottom, this.left, this.right});

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFF8A8A7A), Color(0xFF3A3A30), Color(0xFF1A1A14)],
            stops: [0, 0.7, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.6),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        // Fente, trait sombre tourné 35°.
        child: Center(
          child: Transform.rotate(
            angle: 0.61, // ~35°
            child: Container(
              width: 7,
              height: 2,
              color: const Color(0xFF000000).withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
