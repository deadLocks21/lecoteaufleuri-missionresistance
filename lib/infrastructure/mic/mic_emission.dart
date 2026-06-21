import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/emission_port.dart';
import '../../domain/value_objects/emission_level.dart';
import '../../domain/value_objects/message_id.dart';

/// Adapter réel de [EmissionPort] : branche le micro et fait suivre l'aiguille
/// du VU-mètre à l'**amplitude captée** (BRIEF §2, ARCHITECTURE §9).
///
/// On ouvre un flux PCM uniquement pour garder le micro actif ; les octets sont
/// jetés (rien n'est enregistré ni diffusé). Le niveau vient de
/// `onAmplitudeChanged`, exprimé en dBFS (≤ 0), mappé sur l'échelle 0–10.
///
/// Si la permission micro est refusée, on retombe sur des niveaux aléatoires
/// pour que le poste reste utilisable (jumeau de démo).
class MicEmission implements EmissionPort {
  final AudioRecorder _rec = AudioRecorder();
  final math.Random _rng = math.Random();

  StreamSubscription<Uint8List>? _pcmSub;
  DateTime? _startedAt;
  bool _granted = false;

  /// dBFS planché à ce seuil → 0 sur l'échelle ; 0 dBFS → 10.
  static const double _floorDb = -45;

  @override
  Future<void> start() async {
    _startedAt = DateTime.now();
    _granted = await _rec.hasPermission();
    if (!_granted) return;
    // Flux PCM consommé puis jeté : sert seulement à tenir le micro ouvert.
    final stream = await _rec.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits),
    );
    _pcmSub = stream.listen((_) {});
  }

  @override
  Stream<EmissionLevel> levels() {
    if (!_granted) {
      return Stream<EmissionLevel>.periodic(
        const Duration(milliseconds: 110),
        (_) => EmissionLevel.random(_rng),
      );
    }
    return _rec
        .onAmplitudeChanged(const Duration(milliseconds: 110))
        .map((amp) => _toLevel(amp.current));
  }

  /// Mappe une amplitude dBFS (≤ 0) sur l'échelle 0–10 du VU-mètre.
  EmissionLevel _toLevel(double dbfs) {
    final normalized = ((dbfs - _floorDb) / -_floorDb).clamp(0.0, 1.0);
    return EmissionLevel(normalized * 10);
  }

  @override
  Future<RadioMessage> stop() async {
    final started = _startedAt ?? DateTime.now();
    await _pcmSub?.cancel();
    _pcmSub = null;
    if (_granted) await _rec.stop();
    final duration = DateTime.now().difference(started);
    _startedAt = null;
    return RadioMessage(
      id: MessageId('tx-${started.microsecondsSinceEpoch}'),
      sender: 'CE POSTE',
      sentAt: started,
      duration: duration,
      subtitle: 'Émission locale',
    );
  }
}
