import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/inbox_service.dart';
import '../../strings.dart';
import '../../widgets/section_label.dart';
import 'appel_button.dart';
import 'message_tile.dart';
import 'ptt_button.dart';
import 'vu_meter.dart';

/// Onglet « Trafic radio » (BRIEF §8) : émission (VU-mètre, PTT, appel QG) puis
/// réception (liste de messages réécoutables).
class RadioView extends ConsumerWidget {
  const RadioView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(Strings.sectionEmission, topMargin: 2),
        const VuMeter(),
        const PttButton(),
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
