// Tests de l'écran de fin de scénario (toutes les missions accomplies).
//
// État de démo (MissionProgress.demo) : mission 2 (index 1) en cours sur 4.
// Trois « Mission accomplie » amènent à la dernière mission puis l'accomplissent
// → l'écran de fin s'affiche. On vérifie qu'il se rouvre au ré-appui, que
// « Rester » le referme, et que « Réinitialiser le poste » reverrouille l'app.
// On évite `pumpAndSettle` (bandeau LCD + curseur en boucle) et on démonte
// l'arbre en fin de test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/application/services/tracking_service.dart';
import 'package:mission_resistance/app/mission_resistance_app.dart';
import 'package:mission_resistance/infrastructure/di.dart';
import 'package:mission_resistance/infrastructure/memory/in_memory_session_store.dart';
import 'package:mission_resistance/ui/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Suivi GPS neutralisé : la vraie implémentation touche le canal natif
/// `flutter_foreground_task` (absent en test) et la réinitialisation **attend**
/// son arrêt. On l'isole derrière un jumeau sans plateforme.
class _NoopTracking extends TrackingService {
  @override
  TrackingState build() => const TrackingState(status: TrackingStatus.idle);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop(TrackingStopReason reason) async {
    state = state.copyWith(status: TrackingStatus.stopped, stopReason: reason);
  }

  @override
  Future<void> ensureAlive() async {}
}

Widget _app() => ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
        trackingServiceProvider.overrideWith(_NoopTracking.new),
      ],
      child: const MissionResistanceApp(),
    );

/// Déverrouille le poste (code de démo `6450`) et bascule sur l'onglet Carnet.
Future<void> _openCarnet(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.enterText(find.byType(TextField), '6450');
  await tester.tap(find.text(Strings.unlock));
  await tester.pump(); // Unlocking
  await tester.pump(const Duration(milliseconds: 800)); // transition 750 ms
  await tester.pump(const Duration(milliseconds: 400)); // AnimatedSwitcher
  await tester.tap(find.text(Strings.tabCarnet));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600)); // fin du défilement
}

/// Appuie sur « Mission accomplie » et laisse le carnet se re-rendre.
Future<void> _tapMissionDone(WidgetTester tester) async {
  await tester.tap(find.text(Strings.missionDone));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets(
    "accomplir la dernière mission ouvre l'écran de fin, ré-ouvrable au ré-appui",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openCarnet(tester);

      // Démo : mission 2/4 en cours → 2 appuis atteignent la dernière mission,
      // le 3ᵉ l'accomplit (plus de mission suivante) et ouvre l'écran de fin.
      await _tapMissionDone(tester);
      await _tapMissionDone(tester);
      expect(find.text(Strings.scenarioCompleteTitle), findsNothing);
      await _tapMissionDone(tester);
      await tester.pump(const Duration(milliseconds: 300)); // ouverture du dialog

      expect(find.text(Strings.scenarioCompleteTitle), findsOneWidget);
      expect(find.text(Strings.scenarioCompleteReset), findsOneWidget);

      // « Rester dans la partie » referme l'écran sans quitter le carnet.
      await tester.tap(find.text(Strings.scenarioCompleteStay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(Strings.scenarioCompleteTitle), findsNothing);
      expect(find.text(Strings.missionDone), findsOneWidget);

      // Ré-appuyer sur la dernière mission accomplie rouvre l'écran de fin.
      await _tapMissionDone(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(Strings.scenarioCompleteTitle), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'réinitialiser le poste reverrouille (retour à la saisie du code)',
    (tester) async {
      // La réinitialisation efface des clés `shared_preferences` (progression /
      // scénario en cache) : un magasin simulé suffit, vide en démo.
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openCarnet(tester);

      await _tapMissionDone(tester);
      await _tapMissionDone(tester);
      await _tapMissionDone(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(Strings.scenarioCompleteTitle), findsOneWidget);

      // « Réinitialiser le poste » : arrêt du suivi + purge + reverrouillage.
      await tester.tap(find.text(Strings.scenarioCompleteReset));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // De retour sur l'écran de code : plus de carnet, le bouton Déverrouiller
      // est là.
      expect(find.text(Strings.missionDone), findsNothing);
      expect(find.text(Strings.scenarioCompleteTitle), findsNothing);
      expect(find.text(Strings.unlock), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
