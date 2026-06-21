import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/services/scenario_service.dart';
import '../../../application/services/tracking_service.dart';
import '../../../domain/value_objects/mission_progress.dart';
import '../../state/ticker_controller.dart';
import '../../strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/k_button.dart';
import '../../widgets/section_label.dart';
import 'clue_card.dart';
import 'confirm_modal.dart';

/// Onglet « Carnet de mission » (BRIEF §9) : progression, stepper des missions,
/// et cartes-indices déchiffrables séquentiellement pour la mission en cours.
class CarnetView extends ConsumerWidget {
  const CarnetView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(scenarioServiceProvider).asData?.value;
    if (snapshot == null) return const SizedBox.shrink();

    final total = snapshot.scenario.length;
    final current = snapshot.progress.currentMission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(Strings.carnetTitle, topMargin: 2),
        _ProgressBar(percent: snapshot.percent, current: current, total: total),
        for (var i = 0; i < total; i++) ...[
          _MissionStep(
            index: i,
            current: current,
            title: snapshot.scenario.missionAt(i).title,
            expanded:
                i == current ? _currentMission(context, ref, snapshot) : null,
          ),
          if (i != total - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _currentMission(
    BuildContext context,
    WidgetRef ref,
    ScenarioSnapshot snapshot,
  ) {
    final mission = snapshot.currentMission;
    final progress = snapshot.progress;
    final unlocked = progress.unlockedForCurrent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        for (var k = 0; k < mission.clueCount; k++) ...[
          ClueCard(
            number: k + 1,
            text: mission.clues[k].text,
            state: _cardState(k, unlocked, progress, mission.index),
            onTap: () => _onCardTap(
              context,
              ref,
              k,
              _cardState(k, unlocked, progress, mission.index),
            ),
          ),
          if (k != mission.clueCount - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        Text(
          Strings.clueCount(unlocked, mission.clueCount),
          style: AppText.body(
            size: 11,
            weight: FontWeight.w600,
            color: const Color(0xFFCDBB88),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        KButton(Strings.missionDone, onTap: () => _completeMission(ref)),
      ],
    );
  }

  ClueCardState _cardState(
    int k,
    int unlocked,
    MissionProgress progress,
    int missionIndex,
  ) {
    if (k < unlocked) {
      return progress.isFlipped(missionIndex, k)
          ? ClueCardState.review
          : ClueCardState.revealed;
    }
    if (k == unlocked) return ClueCardState.available;
    return ClueCardState.locked;
  }

  Future<void> _onCardTap(
    BuildContext context,
    WidgetRef ref,
    int k,
    ClueCardState state,
  ) async {
    final service = ref.read(scenarioServiceProvider.notifier);
    final ticker = ref.read(tickerControllerProvider.notifier);

    switch (state) {
      case ClueCardState.available:
        // 1ᵉʳ indice : direct. À partir du 2ᵉ : modal de confirmation.
        if (k >= 1 && !await showDecipherModal(context, k + 1)) return;
        final number = await service.decipherCurrent();
        if (number != null) ticker.show(Strings.tickerClueDeciphered(number));
      case ClueCardState.revealed:
      case ClueCardState.review:
        service.toggleFlip(k);
      case ClueCardState.locked:
        break;
    }
  }

  Future<void> _completeMission(WidgetRef ref) async {
    final advanced =
        await ref.read(scenarioServiceProvider.notifier).completeMission();
    if (!advanced) {
      // Scénario terminé : 1ʳᵉ sécurité d'arrêt du suivi GPS (la date limite
      // est la 2ᵉ, côté TrackingService).
      ref
          .read(trackingServiceProvider.notifier)
          .stop(TrackingStopReason.scenarioComplete);
    }
    ref.read(tickerControllerProvider.notifier).show(
          advanced ? Strings.tickerMissionDone : Strings.tickerScenarioDone,
        );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.percent,
    required this.current,
    required this.total,
  });

  final int percent;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        children: [
          Text(
            Strings.progression,
            style: AppText.body(
              size: 12,
              weight: FontWeight.w700,
              color: TsfPalette.cream,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1F15),
                borderRadius: BorderRadius.circular(5),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [TsfPalette.brass, TsfPalette.brassLight],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$current/$total',
            style: AppText.body(
              size: 12,
              weight: FontWeight.w700,
              color: TsfPalette.cream,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionStep extends StatelessWidget {
  const _MissionStep({
    required this.index,
    required this.current,
    required this.title,
    this.expanded,
  });

  final int index;
  final int current;
  final String title;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final isCurrent = index == current;

    final tag = done
        ? Strings.tagDone
        : isCurrent
            ? Strings.tagCurrent
            : Strings.tagUpcoming;
    final tagColor = isCurrent ? TsfPalette.amber : const Color(0xFF9A9576);
    final titleColor = isCurrent || done
        ? TsfPalette.cream
        : const Color(0xFF8B8A72);

    final step = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? TsfPalette.brassDark : const Color(0xFF1F2117),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isCurrent
              ? const [Color(0xFF4A4E36), Color(0xFF34381F)]
              : const [Color(0xFF3F4330), Color(0x00333725)],
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepNumber(done: done, current: isCurrent, label: '${index + 1}'),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      tag,
                      style: AppText.body(
                        size: 10,
                        weight: FontWeight.w600,
                        color: tagColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                ?expanded,
              ],
            ),
          ),
        ],
      ),
    );

    return done ? Opacity(opacity: 0.62, child: step) : step;
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({
    required this.done,
    required this.current,
    required this.label,
  });

  final bool done;
  final bool current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (done) {
      background = TsfPalette.brassDark;
      foreground = const Color(0xFF1A140A);
    } else if (current) {
      background = TsfPalette.amber;
      foreground = const Color(0xFF3A2A07);
    } else {
      background = const Color(0xFF1D1F15);
      foreground = const Color(0xFF9A9576);
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: current
            ? const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFFFE7A8), TsfPalette.amber],
              )
            : null,
        color: current ? null : background,
        boxShadow: current
            ? [
                BoxShadow(
                  color: const Color(0xFFFF8C1A).withValues(alpha: 0.8),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        done ? '✓' : label,
        style: AppText.display(size: 12, color: foreground, height: 1),
      ),
    );
  }
}
