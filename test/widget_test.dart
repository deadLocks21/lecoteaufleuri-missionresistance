// Smoke tests de l'app « Poste Radio TSF » : verrouillage, erreur de code, et
// déverrouillage avec le code de démo. On évite `pumpAndSettle` car des
// animations en boucle (curseur LCD, bandeau) ne se stabilisent jamais ; on
// démonte l'arbre en fin de test pour libérer timers et tickers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/app/mission_resistance_app.dart';
import 'package:mission_resistance/ui/strings.dart';

void main() {
  testWidgets('démarre sur l\'écran de verrouillage', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MissionResistanceApp()));
    await tester.pump();

    expect(find.text(Strings.locked), findsOneWidget); // plaque VERROUILLÉ
    expect(find.text(Strings.lockPrompt), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un mauvais code affiche une erreur', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MissionResistanceApp()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text(Strings.unlock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // fin du shake

    expect(find.text(Strings.lockHintBad), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('le code 6450 déverrouille le poste', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MissionResistanceApp()));
    await tester.pump();

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
