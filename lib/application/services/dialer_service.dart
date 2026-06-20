import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/di.dart';

/// Déclenche l'appel du QG via [DialerPort] (ARCHITECTURE §12). L'état UI
/// « armé » + reset (2,5 s) est géré côté bouton.
class DialerService {
  DialerService(this._ref);

  final Ref _ref;

  Future<void> callHq() => _ref.read(dialerPortProvider).callHq();
}

final dialerServiceProvider = Provider<DialerService>(DialerService.new);
