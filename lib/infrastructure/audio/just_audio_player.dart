import 'package:just_audio/just_audio.dart';

import '../../domain/ports/player_port.dart';

/// Adapter [PlayerPort] basé sur `just_audio` : joue le clip distant et complète
/// quand la lecture atteint la fin. Une seule instance réutilisée pour tous les
/// messages (un seul flux audio à la fois).
class JustAudioPlayer implements PlayerPort {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(
    String url, {
    void Function()? onPlaying,
    Map<String, String>? headers,
  }) async {
    await _player.stop();
    // chargement/buffering : complète une fois prêt. Les `headers` (dont
    // `X-Partie-Id`) sont indispensables : l'endpoint audio renvoie 400 sans.
    await _player.setUrl(url, headers: headers);
    onPlaying?.call(); // le son va démarrer → passage en « lecture »
    _player.play(); // démarre ; on attend l'événement de fin ci-dessous
    await _player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );
    await _player.stop();
  }

  @override
  Future<void> stop() => _player.stop();

  /// Libère le lecteur natif (appelé par `ref.onDispose`).
  Future<void> dispose() => _player.dispose();
}
