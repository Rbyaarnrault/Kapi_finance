import 'actif_model.dart';

enum TypeEnveloppe { pea, cto, livret, crypto, assuranceVie, per }

class Enveloppe {
  final String id;
  String nom;              // Ex: "PEA Principal", "Livret A"
  final TypeEnveloppe type;
  double pocheCash;              // Espèces non investies disponibles sur ce compte
  List<Actif> actifs;

  Enveloppe({
    required this.id,
    required this.nom,
    required this.type,
    this.pocheCash = 0.0,
    List<Actif>? actifs,
  }) : actifs = actifs ?? [];

  // Valeur totale investie + cash disponible
  double get valeurInvestie => actifs.fold(0.0, (sum, a) => sum + a.valeurTotale);
  double get valeurTotaleEnveloppe => valeurInvestie + pocheCash;

  // Calcul du taux d'imposition selon le type d'enveloppe
  double get tauxImpositionPlusValue {
    switch (type) {
      case TypeEnveloppe.pea:
        return 0.172; // 17.2% Prélèvements sociaux (après 5 ans)
      case TypeEnveloppe.cto:
      case TypeEnveloppe.crypto:
        return 0.30;  // 30% Flat Tax (PFU)
      case TypeEnveloppe.livret:
        return 0.0;   // 0% (Livret A, LDDS)
      default:
        return 0.30;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type': type.name,
      'pocheCash': pocheCash,
      'actifs': actifs.map((a) => a.toMap()).toList(),
    };
  }

  factory Enveloppe.fromMap(Map<String, dynamic> map) {
    return Enveloppe(
      id: map['id'],
      nom: map['nom'],
      type: TypeEnveloppe.values.firstWhere((e) => e.name == map['type']),
      pocheCash: (map['pocheCash'] as num).toDouble(),
      actifs: (map['actifs'] as List).map((a) => Actif.fromMap(a)).toList(),
    );
  }
}