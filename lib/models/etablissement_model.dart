import 'enveloppe_model.dart';

class Etablissement {
  final String id;
  String nom;            // Ex: "Trade Republic", "Boursorama"
  final String logoPath;     
  List<Enveloppe> enveloppes;

  Etablissement({
    required this.id,
    required this.nom,
    this.logoPath = '',
    List<Enveloppe>? enveloppes,
  }) : enveloppes = enveloppes ?? [];

  // Total accumulé dans cette banque
  double get patrimoineTotalEtablissement =>
      enveloppes.fold(0.0, (sum, e) => sum + e.valeurTotaleEnveloppe);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'logoPath': logoPath,
      'enveloppes': enveloppes.map((e) => e.toMap()).toList(),
    };
  }

  factory Etablissement.fromMap(Map<String, dynamic> map) {
    return Etablissement(
      id: map['id'],
      nom: map['nom'],
      logoPath: map['logoPath'] ?? '',
      enveloppes: (map['enveloppes'] as List)
          .map((e) => Enveloppe.fromMap(e))
          .toList(),
    );
  }
}