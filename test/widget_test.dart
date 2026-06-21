// Smoke tests de l'app « Poste Radio TSF » : verrouillage, erreur de code, et
// déverrouillage avec le code de démo. On évite `pumpAndSettle` car des
// animations en boucle (curseur LCD, bandeau) ne se stabilisent jamais ; on
// démonte l'arbre en fin de test pour libérer timers et tickers.
//
// La session est restaurée au démarrage depuis [SessionStore] : on injecte le
// jumeau `InMemorySessionStore` (vide) pour éviter le plugin shared_preferences
// et démarrer verrouillé de façon déterministe.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/app/mission_resistance_app.dart';
import 'package:mission_resistance/infrastructure/di.dart';
import 'package:mission_resistance/infrastructure/memory/in_memory_session_store.dart';
import 'package:mission_resistance/ui/strings.dart';

Widget _app() => ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
      ],
      child: const MissionResistanceApp(),
    );

/// Pompe quelques frames pour laisser la restauration (`Restoring` → `Locked`)
/// se résoudre, sans `pumpAndSettle` (animations en boucle).
Future<void> _bootToLock(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('démarre sur l\'écran de verrouillage', (tester) async {
    await _bootToLock(tester);

    expect(find.text(Strings.locked), findsOneWidget); // plaque VERROUILLÉ
    expect(find.text(Strings.lockPrompt), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un mauvais code affiche une erreur', (tester) async {
    await _bootToLock(tester);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text(Strings.unlock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // fin du shake

    expect(find.text(Strings.lockHintBad), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('le code 6450 déverrouille le poste', (tester) async {
    await _bootToLock(tester);

    await tester.enterText(find.byType(TextField), '6450');
    await tester.tap(find.text(Strings.unlock));
    await tester.pump(); // Unlocking
    await tester.pump(const Duration(milliseconds: 800)); // transition 750 ms
    await tester.pump(const Duration(milliseconds: 400)); // AnimatedSwitcher

    // La plaque affiche le nom d'équipe et la section Émission est visible.
    expect(find.text('LES RENARDS'), findsWidgets);
    expect(find.text(Strings.sectionEmission), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
