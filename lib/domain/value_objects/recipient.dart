/// Équipe ciblable par un poste central / nazi — élément du sélecteur de
/// destinataire (cf. `GET /sessions/:team/radio/status` → `emitter.recipients`).
class Recipient {
  const Recipient({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Recipient && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
