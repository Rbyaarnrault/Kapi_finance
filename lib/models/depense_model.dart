class Depense {
  String id;
  String nom;
  double montant;
  bool isRecurrente;
  bool isCochee; // Payée
  bool isActive;  // Active / Inclusion (Mode Vacances)

  Depense({
    required this.id,
    required this.nom,
    required this.montant,
    this.isRecurrente = false,
    this.isCochee = false,
    this.isActive = true,
  });

  // Convertit un objet en Map pour le stockage futur (SQLite / Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'montant': montant,
      'isRecurrente': isRecurrente ? 1 : 0,
      'isCochee': isCochee ? 1 : 0,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Depense.fromMap(Map<String, dynamic> map) {
    return Depense(
      id: map['id'],
      nom: map['nom'],
      montant: map['montant'],
      isRecurrente: map['isRecurrente'] == 1,
      isCochee: map['isCochee'] == 1,
      isActive: map['isActive'] == 1,
    );
  }
}