enum ModeInvestissement {
  profil1Bankroll, // Budget fixe mensuel réparti en %
  profil2PartsReelles, // Objectif de parts fixes (ex: 1 part Nasdaq + 1 part SP500/mois)
}

class ProfilInvest {
  ModeInvestissement mode;
  double budgetMensuelGlobal; // Pour le Profil 1 (ex: 200 € / mois)

  ProfilInvest({
    this.mode = ModeInvestissement.profil1Bankroll,
    this.budgetMensuelGlobal = 200.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'budgetMensuelGlobal': budgetMensuelGlobal,
    };
  }

  factory ProfilInvest.fromMap(Map<String, dynamic> map) {
    return ProfilInvest(
      mode: ModeInvestissement.values.firstWhere((e) => e.name == map['mode']),
      budgetMensuelGlobal: (map['budgetMensuelGlobal'] as num).toDouble(),
    );
  }
}