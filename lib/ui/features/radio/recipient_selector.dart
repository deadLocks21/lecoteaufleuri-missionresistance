import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/radio_gate_service.dart';
import '../../../application/services/recipient_service.dart';
import '../../../domain/value_objects/message_target.dart';
import '../../../domain/value_objects/radio_gate.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Choix du **destinataire** de la prochaine émission (BRIEF §8 — adressage),
/// affiché uniquement pour un poste central / nazi (cf. `RadioView`, qui masque
/// la section pour un portable). Choix « TOUT LE MONDE » ou une équipe précise.
class RecipientSelector extends ConsumerWidget {
  const RecipientSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate =
        ref.watch(radioGateServiceProvider).asData?.value ?? RadioGate.open;

    // Garde-fou : la vue ne monte ce widget que pour un poste qui adresse.
    if (!gate.canAddress) return const SizedBox.shrink();

    final selected = ref.watch(selectedRecipientProvider);
    final notifier = ref.read(selectedRecipientProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: Strings.recipientEveryone,
          selected: selected is AllTarget,
          onTap: () => notifier.select(MessageTarget.all),
        ),
        for (final r in gate.recipients)
          _Chip(
            label: r.name,
            selected: selected is TeamTarget && selected.id == r.id,
            onTap: () => notifier.select(MessageTarget.team(r.id, r.name)),
          ),
      ],
    );
  }
}

/// Pastille sélectionnable de destinataire (vert LCD si active, olive sinon).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final border = selected ? TsfPalette.greenGlow : const Color(0xFF3B3E2D);
    final fg = selected ? TsfPalette.cream : colors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          color: selected
              ? TsfPalette.green.withValues(alpha: 0.14)
              : const Color(0x00000000),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 12,
            weight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
