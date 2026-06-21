import '../../domain/value_objects/mission_progress.dart';

/// (Dé)sérialisation de [MissionProgress] au **format du contrat API** :
/// `{ "currentMission", "unlocked": [int], "flipped": ["m:k"] }`.
/// `flipped` est un `Set` côté domaine ↔ une liste sur le fil.

MissionProgress progressFromJson(Map<String, dynamic> json) {
  final unlocked = <int>[];
  final rawUnlocked = json['unlocked'];
  if (rawUnlocked is List) {
    for (final v in rawUnlocked) {
      if (v is num) unlocked.add(v.toInt());
    }
  }

  final flipped = <String>{};
  final rawFlipped = json['flipped'];
  if (rawFlipped is List) {
    for (final v in rawFlipped) {
      if (v is String) flipped.add(v);
    }
  }

  return MissionProgress(
    currentMission: (json['currentMission'] as num?)?.toInt() ?? 0,
    unlocked: unlocked,
    flipped: flipped,
  );
}

Map<String, dynamic> progressToJson(MissionProgress progress) => {
      'currentMission': progress.currentMission,
      'unlocked': progress.unlocked,
      'flipped': progress.flipped.toList(),
    };
