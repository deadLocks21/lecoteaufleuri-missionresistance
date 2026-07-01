import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/radio_gate_service.dart';
import '../../../application/services/recipient_service.dart';
import '../../../domain/value_objects/message_target.dart';
import '../../../domain/value_objects/radio_gate.dart';
import '../../../domain/value_objects/recipient.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Choix du **destinataire** de la prochaine émission (BRIEF §8 — adressage),
/// affiché uniquement pour un poste central / nazi (cf. `RadioView`, qui masque
/// la section pour un portable).
///
/// Présenté comme un **cadran d'accord** de poste TSF : une bande LCD que l'on
/// fait défiler (chaque équipe = une « station »), avec une aiguille ambre fixe
/// au centre. La station accordée sous l'aiguille est le destinataire courant.
class RecipientSelector extends ConsumerWidget {
  const RecipientSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate =
        ref.watch(radioGateServiceProvider).asData?.value ?? RadioGate.open;

    // Garde-fou : la vue ne monte ce widget que pour un poste qui adresse.
    if (!gate.canAddress) return const SizedBox.shrink();

    return _RecipientDial(recipients: gate.recipients);
  }
}

/// Une station du cadran : « TOUT LE MONDE » ou une équipe précise.
class _Station {
  const _Station(this.target, this.label);
  final MessageTarget target;
  final String label;
}

class _RecipientDial extends ConsumerStatefulWidget {
  const _RecipientDial({required this.recipients});

  final List<Recipient> recipients;

  @override
  ConsumerState<_RecipientDial> createState() => _RecipientDialState();
}

class _RecipientDialState extends ConsumerState<_RecipientDial> {
  /// Largeur d'une station = fraction de la bande → l'accordée occupe le centre,
  /// ses voisines dépassent de part et d'autre (aperçu du reste de la bande).
  static const double _viewportFraction = 0.44;
  static const double _bandHeight = 78;

  late final PageController _controller;

  List<_Station> get _stations => [
        _Station(MessageTarget.all, Strings.recipientEveryone),
        for (final r in widget.recipients)
          _Station(MessageTarget.team(r.id, r.name), r.name),
      ];

  /// Index de la station correspondant à une cible (0 = « tout le monde »).
  int _indexOf(MessageTarget target) {
    if (target is TeamTarget) {
      final i = widget.recipients.indexWhere((r) => r.id == target.id);
      return i < 0 ? 0 : i + 1;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    final index = _indexOf(ref.read(selectedRecipientProvider));
    _controller = PageController(
      viewportFraction: _viewportFraction,
      initialPage: index,
    );
  }

  @override
  void didUpdateWidget(_RecipientDial old) {
    super.didUpdateWidget(old);
    // La liste d'équipes a changé (régie) → recale si l'accord dépasse la bande.
    if (old.recipients.length != widget.recipients.length &&
        _controller.hasClients) {
      final max = _stations.length - 1;
      if ((_controller.page ?? 0) > max) _controller.jumpToPage(max);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Position fractionnaire courante du cadran (pour l'animation des libellés).
  double _page(int fallback) {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? fallback.toDouble();
    }
    return fallback.toDouble();
  }

  void _onPageChanged(int i) {
    final stations = _stations;
    if (i >= 0 && i < stations.length) {
      ref.read(selectedRecipientProvider.notifier).select(stations[i].target);
    }
  }

  void _tuneTo(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexOf(ref.watch(selectedRecipientProvider));
    final stations = _stations;

    // Reset externe (ex. changement d'équipe → retour à « tout le monde ») :
    // on ré-accorde le cadran sans reboucler (garde sur la page déjà centrée).
    ref.listen(selectedRecipientProvider, (_, next) {
      final target = _indexOf(next);
      if (_controller.hasClients && _controller.page?.round() != target) {
        _tuneTo(target);
      }
    });

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: TsfPalette.brassDark, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: _bandHeight,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: TsfPalette.lcdBg)),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _DialScalePainter())),
              ),
              Positioned.fill(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  itemCount: stations.length,
                  itemBuilder: (context, i) => _StationLabel(
                    label: stations[i].label,
                    distanceFrom: () => (i - _page(selectedIndex)).abs(),
                    animation: _controller,
                    onTap: () => _tuneTo(i),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _NeedlePainter())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellé d'une station : s'éclaircit et grandit en approchant du centre (effet
/// « accord » du poste). L'animation suit le défilement continu du cadran.
class _StationLabel extends StatelessWidget {
  const _StationLabel({
    required this.label,
    required this.distanceFrom,
    required this.animation,
    required this.onTap,
  });

  final String label;

  /// Distance (en pages) de cette station au centre, réévaluée à chaque frame.
  final double Function() distanceFrom;
  final Listenable animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = (1 - distanceFrom()).clamp(0.0, 1.0);
          final color = Color.lerp(
            const Color(0xFF2F6B3D),
            const Color(0xFFB6FFC2),
            t,
          )!;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppText.mono(size: 13 + 6 * t, color: color, letterSpacing: 1)
                      .copyWith(
                    shadows: t > 0.55
                        ? [
                            Shadow(
                              color: TsfPalette.greenGlow
                                  .withValues(alpha: (t - 0.55) * 1.6),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Filet de graduation façon échelle de fréquences, en bas de la bande LCD.
class _DialScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TsfPalette.green.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    const step = 14.0;
    var n = 0;
    for (double x = step; x < size.width; x += step) {
      final h = (n % 4 == 0) ? 12.0 : 6.0;
      canvas.drawLine(Offset(x, size.height - 5), Offset(x, size.height - 5 - h), paint);
      n++;
    }
  }

  @override
  bool shouldRepaint(_DialScalePainter oldDelegate) => false;
}

/// Repères d'accord ambre, fixes au centre : un triangle + un court trait en haut
/// **et** en bas, qui encadrent le créneau accordé sans traverser le libellé de
/// la station. Halo diffus pour l'effet « voyant ».
class _NeedlePainter extends CustomPainter {
  /// Longueur des traits depuis chaque bord (le milieu reste libre pour le texte).
  static const double _stub = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final glow = Paint()
      ..color = TsfPalette.amberGlow.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..color = TsfPalette.amber
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final tri = Paint()..color = TsfPalette.amber;

    // Haut : trait descendant + triangle pointant vers le bas.
    canvas.drawLine(Offset(cx, 3), Offset(cx, _stub), glow);
    canvas.drawLine(Offset(cx, 0), Offset(cx, _stub), line);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 7, 0)
        ..lineTo(cx + 7, 0)
        ..lineTo(cx, 11)
        ..close(),
      tri,
    );

    // Bas : trait montant + triangle pointant vers le haut.
    canvas.drawLine(Offset(cx, size.height - _stub), Offset(cx, size.height - 3), glow);
    canvas.drawLine(Offset(cx, size.height - _stub), Offset(cx, size.height), line);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 7, size.height)
        ..lineTo(cx + 7, size.height)
        ..lineTo(cx, size.height - 11)
        ..close(),
      tri,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}
