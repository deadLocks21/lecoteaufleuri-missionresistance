import 'package:just_audio/just_audio.dart';

import '../../domain/ports/player_port.dart';

/// Adapter [PlayerPort] basé sur `just_audio` : joue le clip distant et complète
/// quand la lecture atteint la fin. Une seule instance réutilisée pour tous les
/// messages (un seul flux audio à la fois).
class JustAudioPlayer implements PlayerPort {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String url) async {
    await _player.stop();
    await _player.setUrl(url);
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
