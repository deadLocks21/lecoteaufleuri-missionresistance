import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:record/record.dart';

import '../../domain/ports/emission_port.dart';
import '../../domain/value_objects/emission_level.dart';
import '../../domain/value_objects/recording.dart';

/// Adapter réel de [EmissionPort] : branche le micro, fait suivre l'aiguille du
/// VU-mètre à l'**amplitude captée** (BRIEF §2, ARCHITECTURE §9) **et enregistre
/// l'audio** dans un fichier temporaire (AAC-LC / `.m4a`) que [OutboxPort]
/// diffuse ensuite.
///
/// Le niveau vient de `onAmplitudeChanged`, exprimé en dBFS (≤ 0), mappé sur
/// l'échelle 0–10. Si la permission micro est refusée, on retombe sur des
/// niveaux aléatoires et aucun audio n'est capté (`stop()` renvoie `null`) pour
/// que le poste reste utilisable.
class MicEmission implements EmissionPort {
  final AudioRecorder _rec = AudioRecorder();
  final math.Random _rng = math.Random();

  DateTime? _startedAt;
  String? _path;
  bool _granted = false;

  /// dBFS planché à ce seuil → 0 sur l'échelle ; 0 dBFS → 10.
  static const double _floorDb = -45;
  static const String _contentType = 'audio/mp4';

  @override
  Future<void> start() async {
    _startedAt = DateTime.now();
    _granted = await _rec.hasPermission();
    if (!_granted) return;
    final path =
        '${Directory.systemTemp.path}/tx_${_startedAt!.microsecondsSinceEpoch}.m4a';
    _path = path;
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
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
  Future<Recording?> stop() async {
    final started = _startedAt ?? DateTime.now();
    _startedAt = null;
    final duration = DateTime.now().difference(started);
    if (!_granted) {
      _path = null;
      return null;
    }
    // `stop()` renvoie le chemin réellement écrit ; repli sur celui demandé.
    final recordedPath = await _rec.stop() ?? _path;
    _path = null;
    if (recordedPath == null) return null;
    return Recording(
      path: recordedPath,
      duration: duration,
      contentType: _contentType,
    );
  }
}
