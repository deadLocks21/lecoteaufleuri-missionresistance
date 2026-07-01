import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/config/timings.dart';
import '../../../application/services/emission_service.dart';
import '../../state/ticker_controller.dart';
import '../../strings.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_icons.dart';

/// Bouton TRANSMETTRE — push-to-talk (BRIEF §8.1.b). Appui maintenu → émission
/// (rouge enfoncé, chrono, voyant pulsé) ; relâché → envoi. Quand [enabled] est
/// `false` (radio coupée par la régie), le bouton est grisé, verrouillé et inerte.
class PttButton extends ConsumerWidget {
  const PttButton({super.key, this.enabled = true});

  /// `false` → émission impossible (radio coupée) : bouton grisé et non réactif.
  final bool enabled;

  void _start(WidgetRef ref) {
    ref.read(emissionServiceProvider.notifier).startTx();
    ref.read(tickerControllerProvider.notifier).show(Strings.tickerTxLive);
  }

  Future<void> _stop(WidgetRef ref) async {
    if (!ref.read(emissionServiceProvider).isLive) return;
    final seconds = await ref.read(emissionServiceProvider.notifier).stopTx();
    ref.read(tickerControllerProvider.notifier).show(Strings.tickerTxSent(seconds));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const _BlockedPtt();
    final phase = ref.watch(emissionServiceProvider.select((s) => s.phase));
    final seconds = ref.watch(emissionServiceProvider.select((s) => s.seconds));
    final live = phase == EmissionPhase.live;

    final title = live ? Strings.transmitting : Strings.transmit;
    final subtitle = switch (phase) {
      EmissionPhase.live => Strings.pttRecording(seconds),
      EmissionPhase.sent => Strings.pttSent(seconds),
      EmissionPhase.idle => Strings.pttHint,
    };
    final fg = live ? const Color(0xFFFFFFFF) : const Color(0xFF10210F);

    return Listener(
      onPointerDown: (_) => _start(ref),
      onPointerUp: (_) => _stop(ref),
      onPointerCancel: (_) => _stop(ref),
      child: Transform.translate(
        offset: Offset(0, live ? 6 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: RadialGradient(
              center: const Alignment(0, -0.76),
              radius: 1.3,
              colors: live
                  ? const [Color(0xFFD98C78), Color(0xFFB3331E), Color(0xFF6F1C10)]
                  : const [Color(0xFFC7D0A0), Color(0xFF8C9B5F), Color(0xFF5C6A35)],
              stops: [0, live ? 0.6 : 0.55, 1],
            ),
            boxShadow: live
                ? [
                    BoxShadow(
                      color: const Color(0xFF3C4622),
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Color(0xFF3C4622),
                      offset: Offset(0, 7),
                    ),
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.45),
                      offset: const Offset(0, 12),
                      blurRadius: 16,
                    ),
                  ],
          ),
          child: Row(
            children: [
              AppIcons.mic(30, fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.display(size: 18, color: fg, height: 1.1, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: fg.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PulseDot(live: live),
            ],
          ),
        ),
      ),
    );
  }
}

/// Variante grisée et verrouillée du bouton TRANSMETTRE, affichée quand la régie
/// a coupé la radio : aspect olive éteint, cadenas, et **aucune interaction**
/// (pas de `Listener`, donc l'appui n'ouvre pas le micro).
class _BlockedPtt extends StatelessWidget {
  const _BlockedPtt();

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFFC7C3A8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const RadialGradient(
          center: Alignment(0, -0.76),
          radius: 1.3,
          colors: [Color(0xFF6E7358), Color(0xFF4C5039), Color(0xFF343827)],
          stops: [0, 0.6, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF191A12), offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          AppIcons.lock(28, fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Strings.transmit,
                  style: AppText.display(size: 18, color: fg, height: 1.1, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  Strings.pttBlocked,
                  style: AppText.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
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

/// Voyant rond du PTT : vert au repos, rouge **pulsé** (0,7 s) en émission.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.live});

  final bool live;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Timings.pttLivePulse,
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.live && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.live && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.live ? const Color(0xFFB3331E) : const Color(0xFF7FE389);
    final glow = widget.live ? const Color(0xFFFF6A43) : const Color(0xFF36D24C);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = widget.live ? _c.value : 0.0;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [
                widget.live ? const Color(0xFFFFD9CF) : const Color(0xFFDFFFE0),
                base,
              ],
            ),
            boxShadow: [
              BoxShadow(color: glow, blurRadius: 8 + 6 * t),
            ],
          ),
        );
      },
    );
  }
}
