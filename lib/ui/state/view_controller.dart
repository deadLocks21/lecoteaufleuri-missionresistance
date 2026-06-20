import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet courant du shell (BRIEF §5.1).
enum ShellTab { radio, mission }

/// Onglet affiché, piloté par l'interrupteur à bascule.
class ViewController extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.radio;

  void set(ShellTab view) => state = view;

  void toggle() =>
      state = state == ShellTab.radio ? ShellTab.mission : ShellTab.radio;
}

final viewControllerProvider =
    NotifierProvider<ViewController, ShellTab>(ViewController.new);
