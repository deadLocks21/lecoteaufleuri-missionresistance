// Tests de l'onglet « Carnet de mission » : seules les missions débloquées
// (terminées + en cours) sont affichées, les missions terminées se déplient
// pour revoir leurs indices déchiffrés, et la mission en cours reste déployée.
//
// État de démo (MissionProgress.demo) : mission 1 (index 0) terminée avec
// 2 indices déchiffrés, mission 2 (index 1) en cours, missions 3-4 à venir.
// On évite `pumpAndSettle` (bandeau LCD + curseur en boucle) et on démonte
// l'arbre en fin de test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/app/mission_resistance_app.dart';
import 'package:mission_resistance/infrastructure/di.dart';
import 'package:mission_resistance/infrastructure/memory/demo_data.dart';
import 'package:mission_resistance/infrastructure/memory/in_memory_session_store.dart';
import 'package:mission_resistance/ui/strings.dart';

Widget _app() => ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
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
  await tester.pump(const Duration(milliseconds: 600)); // fin du défilement d'entrée
}

void main() {
  final scenario = DemoData.scenario();
  final done = scenario.missionAt(0); // terminée, 2 indices déchiffrés
  final current = scenario.missionAt(1); // en cours
  final upcomingA = scenario.missionAt(2); // à venir (masquée)
  final upcomingB = scenario.missionAt(3); // à venir (masquée)

  testWidgets(
    'masque les missions à venir et déplie les missions terminées',
    (tester) async {
      // Surface large (police de test Ahem) et haute : tout tient à l'écran, le
      // défilement d'entrée ne masque aucune mission et reste un no-op.
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openCarnet(tester);

      // Missions débloquées visibles, missions à venir masquées.
      expect(find.text(done.title), findsOneWidget);
      expect(find.text(current.title), findsOneWidget);
      expect(find.text(upcomingA.title), findsNothing);
      expect(find.text(upcomingB.title), findsNothing);

      // La mission en cours est déployée (bouton « Mission accomplie »).
      expect(find.text(Strings.missionDone), findsOneWidget);

      // La mission terminée est repliée par défaut : indices masqués.
      expect(find.text(done.clues[0].text), findsNothing);

      // Déplier révèle tous ses indices (lecture seule).
      await tester.tap(find.text(done.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // AnimatedSize
      expect(find.text(done.clues[0].text), findsOneWidget);
      expect(find.text(done.clues[1].text), findsOneWidget);

      // Replier les masque de nouveau.
      await tester.tap(find.text(done.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(done.clues[0].text), findsNothing);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'une mission terminée affiche tous ses indices, même non déchiffrés',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openCarnet(tester);

      // Terminer la mission en cours (index 1, 3 indices) sans en déchiffrer
      // aucun : elle devient une mission passée avec 0 indice déchiffré.
      await tester.tap(find.text(Strings.missionDone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700)); // re-rendu carnet

      // Repliée par défaut, puis dépliée : ses 3 indices s'affichent tous,
      // bien qu'aucun n'ait été déchiffré.
      expect(find.text(current.clues[0].text), findsNothing);
      await tester.tap(find.text(current.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // AnimatedSize
      expect(find.text(current.clues[0].text), findsOneWidget);
      expect(find.text(current.clues[1].text), findsOneWidget);
      expect(find.text(current.clues[2].text), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
