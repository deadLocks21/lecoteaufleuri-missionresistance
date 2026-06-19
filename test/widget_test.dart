// Smoke test : l'app démarre et affiche l'écran de marque « Mission Résistance ».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mission_resistance/main.dart';

void main() {
  testWidgets('affiche l\'écran de marque au démarrage', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MissionResistanceApp()));

    expect(find.text('Mission Résistance'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
