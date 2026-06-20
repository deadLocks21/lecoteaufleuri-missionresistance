import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/config/timings.dart';
import '../../../application/services/dialer_service.dart';
import '../../state/ticker_controller.dart';
import '../../strings.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_icons.dart';

/// Bouton APPEL QG (BRIEF §8.1.c) : rouge, déclenche l'appel téléphonique réel.
/// État « armé » (enfoncé + pulsation rouge) puis reset après 2,5 s.
class AppelButton extends ConsumerStatefulWidget {
  const AppelButton({super.key});

  @override
  ConsumerState<AppelButton> createState() => _AppelButtonState();
}

class _AppelButtonState extends ConsumerState<AppelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Timings.appelPulse,
  );
  bool _armed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_armed) return;
    setState(() => _armed = true);
    _pulse.repeat(reverse: true);
    ref.read(tickerControllerProvider.notifier).show(Strings.tickerAppel);
    await ref.read(dialerServiceProvider).callHq();
    await Future<void>.delayed(Timings.appelReset);
    if (!mounted) return;
    setState(() => _armed = false);
    _pulse
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final subtext = _armed ? Strings.appelInProgress : Strings.appelHelp;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 11),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _armed ? _pulse.value : 0.0;
            return Transform.translate(
              offset: Offset(0, _armed ? 4 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.76),
                    radius: 1.3,
                    colors: [Color(0xFFE06A54), Color(0xFFB3331E), Color(0xFF6F1C10)],
                    stops: [0, 0.58, 1],
                  ),
                  boxShadow: _armed
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6A43).withValues(alpha: 0.3 + 0.4 * t),
                            blurRadius: 8 + 8 * t,
                          ),
                          const BoxShadow(
                            color: Color(0xFF4D130A),
                            offset: Offset(0, 1),
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Color(0xFF4D130A),
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF000000).withValues(alpha: 0.4),
                            offset: const Offset(0, 7),
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcons.alert(22, const Color(0xFFFFFFFF)),
                    const SizedBox(width: 9),
                    Text.rich(
                      TextSpan(
                        text: Strings.appel,
                        style: AppText.display(
                          size: 13,
                          color: const Color(0xFFFFFFFF),
                          letterSpacing: 0.5,
                        ),
                        children: [
                          TextSpan(
                            text: '  $subtext',
                            style: AppText.body(
                              size: 10,
                              weight: FontWeight.w600,
                              color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
