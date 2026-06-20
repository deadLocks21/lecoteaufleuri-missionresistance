import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../application/config/timings.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_curves.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_icons.dart';

/// État d'affichage d'une carte-indice (BRIEF §9.3).
enum ClueCardState {
  /// Déchiffrée, face visible (papier).
  revealed,

  /// Déchiffrée mais repliée (cover « toucher pour revoir »).
  review,

  /// Disponible (suivante à déchiffrer).
  available,

  /// Verrouillée (cadenas, inerte).
  locked,
}

/// Carte-indice à retournement 3D (flip Y, 0,6 s). Dos pochoir / face papier.
class ClueCard extends StatefulWidget {
  const ClueCard({
    super.key,
    required this.number,
    required this.text,
    required this.state,
    this.onTap,
  });

  final int number;
  final String text;
  final ClueCardState state;
  final VoidCallback? onTap;

  bool get _showsContent => state == ClueCardState.revealed;

  @override
  State<ClueCard> createState() => _ClueCardState();
}

class _ClueCardState extends State<ClueCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Timings.flip,
    value: widget._showsContent ? 1 : 0,
  );

  @override
  void didUpdateWidget(ClueCard old) {
    super.didUpdateWidget(old);
    if (widget._showsContent != old._showsContent) {
      if (widget._showsContent) {
        _c.animateTo(1, curve: AppCurves.standard);
      } else {
        _c.animateBack(0, curve: AppCurves.standard);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 72,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final angle = _c.value * math.pi;
            final showFront = _c.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: showFront
                  ? _Cover(state: widget.state, number: widget.number)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _Content(number: widget.number, text: widget.text),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.state, required this.number});

  final ClueCardState state;
  final int number;

  @override
  Widget build(BuildContext context) {
    final locked = state == ClueCardState.locked;
    final fg = locked ? const Color(0xFF6B6C5C) : TsfPalette.cream;
    final sub = switch (state) {
      ClueCardState.revealed => Strings.coverDeciphered,
      ClueCardState.review => Strings.coverReview,
      ClueCardState.available => Strings.coverDecipher,
      ClueCardState.locked => Strings.coverLocked,
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: locked ? const Color(0xFF15160F) : TsfPalette.brassDark,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: locked
              ? const [Color(0xFF26281C), Color(0xFF1A1C12)]
              : const [Color(0xFF5A5F44), Color(0xFF3D4130)],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Strings.clueCover(number),
            style: AppText.display(size: 15, color: fg, letterSpacing: 1),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                AppIcons.lock(13, fg),
                const SizedBox(width: 5),
              ],
              Text(
                sub,
                style: AppText.body(
                  size: 10,
                  weight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: TsfPalette.paperBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.clueLabel(number),
                  style: AppText.body(
                    size: 10,
                    weight: FontWeight.w700,
                    color: TsfPalette.paperLabel,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: AppText.mono(
                    size: 12.5,
                    color: TsfPalette.paperText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
