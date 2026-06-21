import '../../domain/entities/mission.dart';
import '../../domain/entities/scenario.dart';

/// (Dé)sérialisation d'un [Scenario] au **format du contrat API**, partagé par
/// l'endpoint, le cache local et la régie :
/// `{ "missions": [ { "index", "title", "clues": [ { "index", "text" } ] } ] }`.
///
/// Parsing **défensif** : un champ manquant/typé faux ne casse pas le tout
/// (on retombe sur une valeur sûre / l'index de position).

Scenario scenarioFromJson(Map<String, dynamic> json) {
  final rawMissions = json['missions'];
  if (rawMissions is! List) return const Scenario(missions: []);

  final missions = <Mission>[];
  for (var i = 0; i < rawMissions.length; i++) {
    final m = rawMissions[i];
    if (m is! Map) continue;
    final clues = <Clue>[];
    final rawClues = m['clues'];
    if (rawClues is List) {
      for (var j = 0; j < rawClues.length; j++) {
        final cl = rawClues[j];
        if (cl is! Map) continue;
        clues.add(Clue(
          index: (cl['index'] as num?)?.toInt() ?? j,
          text: cl['text'] as String? ?? '',
        ));
      }
    }
    missions.add(Mission(
      index: (m['index'] as num?)?.toInt() ?? i,
      title: m['title'] as String? ?? '',
      clues: clues,
    ));
  }
  return Scenario(missions: missions);
}

Map<String, dynamic> scenarioToJson(Scenario scenario) => {
      'missions': [
        for (final m in scenario.missions)
          {
            'index': m.index,
            'title': m.title,
            'clues': [
              for (final c in m.clues) {'index': c.index, 'text': c.text},
            ],
          },
      ],
    };
