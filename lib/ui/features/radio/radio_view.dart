import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/inbox_service.dart';
import '../../../application/services/radio_gate_service.dart';
import '../../../domain/value_objects/radio_gate.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/section_label.dart';
import 'appel_button.dart';
import 'message_tile.dart';
import 'ptt_button.dart';
import 'vu_meter.dart';

/// Onglet « Trafic radio » (BRIEF §8) : émission (VU-mètre, PTT, appel QG) puis
/// réception (liste de messages réécoutables). Quand la régie a **coupé la
/// radio** (et que ce poste n'est pas exempté), un bandeau d'alerte s'affiche et
/// le bouton TRANSMETTRE est grisé.
class RadioView extends ConsumerWidget {
  const RadioView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxServiceProvider);
    final gate = ref.watch(radioGateServiceProvider).asData?.value ?? RadioGate.open;
    final denied = gate.emissionDenied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (denied) const _RadioBlockedBanner(),
        const SectionLabel(Strings.sectionEmission, topMargin: 2),
        const VuMeter(),
        PttButton(enabled: !denied),
        const AppelButton(),
        const SectionLabel(Strings.sectionReception),
        ...inbox.maybeWhen(
          data: (messages) => [
            for (var i = 0; i < messages.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == messages.length - 1 ? 0 : 8),
                child: MessageTile(message: messages[i]),
              ),
          ],
          orElse: () => const [SizedBox.shrink()],
        ),
      ],
    );
  }
}

/// Bandeau d'alerte « radio coupée » : le poste central est tombé aux mains des
/// Allemands, l'émission est suspendue pour ce poste.
class _RadioBlockedBanner extends StatelessWidget {
  const _RadioBlockedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.emit.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.emit.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcons.alert(22, colors.emit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.radioBlockedTitle,
                  style: AppText.display(size: 14, color: colors.emit, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  Strings.radioBlockedNotice,
                  style: AppText.body(size: 13, color: colors.textPrimary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
