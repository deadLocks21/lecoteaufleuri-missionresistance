import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/config/timings.dart';
import '../../../application/services/inbox_service.dart';
import '../../../domain/entities/radio_message.dart';
import '../../state/ticker_controller.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_icons.dart';

/// Carte d'un message reçu (BRIEF §8.2). États `unread` / `heard` / `playing`,
/// réécoutable à volonté.
class MessageTile extends ConsumerWidget {
  const MessageTile({super.key, required this.message});

  final RadioMessage message;

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _play(WidgetRef ref) async {
    if (message.isActive) return;
    final ticker = ref.read(tickerControllerProvider.notifier);
    ticker.show(Strings.tickerPlaying(message.sender));
    await ref.read(inboxServiceProvider.notifier).play(message.id);
    ticker.show(Strings.tickerPlayed(message.sender));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = message.isLoading;
    final playing = message.isPlaying;
    final active = message.isActive;
    final heard = message.isHeard;
    final badge = message.mine
        ? Strings.badgeSent
        : (message.isUnread ? Strings.badgeNew : Strings.badgeReplay);
    final badgeColor = message.mine
        ? TsfPalette.green
        : (message.isUnread ? TsfPalette.amber : const Color(0xFF9A9576));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _play(ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? TsfPalette.greenGlow : const Color(0xFF1F2117),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3F4330), Color(0x00333725)],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: TsfPalette.greenGlow.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _Mlamp(unread: message.isUnread),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          message.sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: TsfPalette.cream,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge,
                        style: AppText.body(
                          size: 10,
                          weight: FontWeight.w600,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _hhmm(message.sentAt),
                        style: AppText.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF9A9576),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(size: 11, color: const Color(0xFFA9B389)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (loading)
              const _Spinner()
            else if (playing)
              const _Equalizer()
            else ...[
              Text(
                _mmss(message.duration),
                style: AppText.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: TsfPalette.amber,
                ),
              ),
              const SizedBox(width: 10),
              AppIcons.play(
                18,
                heard ? const Color(0xFF9A9576) : TsfPalette.green,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mlamp extends StatelessWidget {
  const _Mlamp({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unread ? null : const Color(0xFF3B3E2D),
        gradient: unread
            ? const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFFFF0CF), Color(0xFFFFB13A)],
              )
            : null,
        boxShadow: unread
            ? [
                BoxShadow(
                  color: const Color(0xFFFF8C1A).withValues(alpha: 0.9),
                  blurRadius: 9,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Spinner de chargement, visible pendant le buffering du clip (avant le début
/// réel de la lecture). Arc vert tournant, dans l'emprise de l'égaliseur (16px).
class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(painter: _SpinnerPainter()),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    // Piste discrète.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TsfPalette.green.withValues(alpha: 0.2),
    );
    // Arc actif (~270°).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = TsfPalette.green,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => false;
}

/// Égaliseur 4 barres animées, visible pendant la lecture (BRIEF §8.2).
class _Equalizer extends StatefulWidget {
  const _Equalizer();

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Timings.equalizer,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 0.15, 0.3, 0.45];
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final phase in phases) ...[
                Container(
                  width: 3,
                  height: 4 + 12 * (0.5 + 0.5 * math.sin((_c.value + phase) * 2 * math.pi)),
                  decoration: BoxDecoration(
                    color: TsfPalette.green,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                if (phase != phases.last) const SizedBox(width: 2),
              ],
            ],
          );
        },
      ),
    );
  }
}
