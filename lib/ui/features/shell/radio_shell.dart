import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/scenario_service.dart';
import '../../../application/session/session_controller.dart';
import '../../../domain/entities/team.dart';
import '../../state/ticker_controller.dart';
import '../../state/view_controller.dart';
import '../../strings.dart';
import '../../widgets/id_plate.dart';
import '../../widgets/lcd_ticker.dart';
import '../../widgets/panel_scaffold.dart';
import '../../widgets/toggle_switch.dart';
import '../carnet/carnet_view.dart';
import '../radio/radio_view.dart';

/// Shell à deux onglets affiché après déverrouillage (BRIEF §5.1) : en-tête
/// commun (plaque + bascule + bandeau LCD) et corps qui bascule entre Radio et
/// Carnet sans rechargement.
class RadioShell extends ConsumerStatefulWidget {
  const RadioShell({super.key});

  @override
  ConsumerState<RadioShell> createState() => _RadioShellState();
}

class _RadioShellState extends ConsumerState<RadioShell> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(ShellTab view) {
    ref.read(viewControllerProvider.notifier).set(view);
    ref.read(tickerControllerProvider.notifier).clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _defaultTicker(ShellTab view, Team team) {
    if (view == ShellTab.radio) return Strings.tickerRadio(team.channel);
    final snapshot = ref.watch(scenarioServiceProvider).asData?.value;
    if (snapshot == null) return '…';
    if (snapshot.scenario.missions.isEmpty) return Strings.tickerScenarioPending;
    final mission = snapshot.currentMission;
    return Strings.tickerMission(
      snapshot.progress.currentMission + 1,
      snapshot.scenario.length,
      mission.title,
      snapshot.progress.unlockedForCurrent,
      mission.clueCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final team = session is Unlocked ? session.team : null;
    if (team == null) return const SizedBox.shrink();

    final view = ref.watch(viewControllerProvider);
    final transient = ref.watch(tickerControllerProvider);
    final tickerText = transient ?? _defaultTicker(view, team);

    return PanelScaffold(
      scrollController: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IdPlate(team: team.name),
          ToggleSwitch(view: view, onChanged: _onChanged),
          LcdTicker(text: tickerText),
          if (view == ShellTab.radio)
            const RadioView()
          else
            const CarnetView(),
        ],
      ),
    );
  }
}
