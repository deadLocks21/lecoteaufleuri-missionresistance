import 'package:url_launcher/url_launcher.dart';

import '../../domain/ports/dialer_port.dart';

/// Adapter réel de [DialerPort] : ouvre le composeur du téléphone via un lien
/// `tel:` (iOS `tel://`, Android `ACTION_DIAL`). Ne compose jamais en silence —
/// l'OS demande confirmation (BRIEF §13 / ARCHITECTURE §12).
///
/// Sur desktop / web (pas de téléphonie), l'échec est avalé pour ne pas
/// interrompre l'expérience : l'UI a déjà affiché l'état « appel en cours ».
class UrlLauncherDialer implements DialerPort {
  UrlLauncherDialer(this.number);

  final String number;

  @override
  Future<void> callHq() async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (_) {
      // Aucun composeur disponible : on n'interrompt pas le flux.
    }
  }
}
