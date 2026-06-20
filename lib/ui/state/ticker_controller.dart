import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/config/timings.dart';

/// Message **transitoire** du bandeau LCD (null = afficher le défaut de l'onglet).
/// Revient automatiquement au défaut après 1,8 s (BRIEF §6.2).
class TickerController extends Notifier<String?> {
  Timer? _revert;

  @override
  String? build() {
    ref.onDispose(() => _revert?.cancel());
    return null;
  }

  /// Affiche un message transitoire puis revient au défaut.
  void show(String message) {
    state = message;
    _revert?.cancel();
    _revert = Timer(Timings.tickerRevert, () => state = null);
  }

  /// Efface immédiatement le transitoire (ex. au changement d'onglet).
  void clear() {
    _revert?.cancel();
    state = null;
  }
}

final tickerControllerProvider =
    NotifierProvider<TickerController, String?>(TickerController.new);
