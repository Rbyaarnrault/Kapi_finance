enum TypeActif { etf, action, crypto, cash }

class Actif {
  final String id;
  String nom;              // Ex: "Amundi PEA Nasdaq 100 Acc"
  final String ticker;           // Ex: "PUST.PA" ou "6006.PA"
  final String isin;             // Ex: "FR0011871128"
  final String bourse;           // Ex: "Euronext Paris"
  final String devise;           // Ex: "EUR", "USD"
  final TypeActif type;
  final double fraisGestion;
  // Données Utilisateur
  double nombreParts;            // Nombre de parts possédées
  double pru;                    // Prix de Revient Unitaire (€)
  
  // Données Profil 1 (Bankroll)
  double pourcentageCible;       // Ex: 50% de l'allocation mensuelle
  double bankrollActuelle;       // Réserve accumulée en € pour cet actif

  // Données Marché (Mises à jour via API Yahoo)
  double prixActuel;             // Dernier prix connu
  double variation24h;           // Variation en %

  Actif({
    required this.id,
    required this.nom,
    required this.ticker,
    this.isin = '',
    this.bourse = 'Euronext Paris',
    this.devise = 'EUR',
    this.type = TypeActif.etf,
    this.nombreParts = 0.0,
    this.pru = 0.0,
    this.pourcentageCible = 0.0,
    this.bankrollActuelle = 0.0,
    this.prixActuel = 0.0,
    this.variation24h = 0.0,
    this.fraisGestion = 0.0,
  });

  // Calculs financiers automatiques
  double get valeurTotale => nombreParts * prixActuel;
  double get plusValueLatenteEuro => (prixActuel - pru) * nombreParts;
  double get plusValueLatentePourcent => pru > 0 ? ((prixActuel - pru) / pru) * 100 : 0.0;

  // Convertit en Map pour la sauvegarde (SQLite / Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'ticker': ticker,
      'isin': isin,
      'bourse': bourse,
      'devise': devise,
      'type': type.name,
      'nombreParts': nombreParts,
      'pru': pru,
      'pourcentageCible': pourcentageCible,
      'bankrollActuelle': bankrollActuelle,
      'prixActuel': prixActuel,
      'variation24h': variation24h,
    };
  }

  factory Actif.fromMap(Map<String, dynamic> map) {
    return Actif(
      id: map['id'],
      nom: map['nom'],
      ticker: map['ticker'],
      isin: map['isin'] ?? '',
      bourse: map['bourse'] ?? 'Euronext Paris',
      devise: map['devise'] ?? 'EUR',
      type: TypeActif.values.firstWhere((e) => e.name == map['type']),
      nombreParts: (map['nombreParts'] as num).toDouble(),
      pru: (map['pru'] as num).toDouble(),
      pourcentageCible: (map['pourcentageCible'] as num).toDouble(),
      bankrollActuelle: (map['bankrollActuelle'] as num).toDouble(),
      prixActuel: (map['prixActuel'] as num).toDouble(),
      variation24h: (map['variation24h'] as num).toDouble(),
    );
  }
}