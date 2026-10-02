import 'package:flutter/material.dart';
import '../models/depense_model.dart';
import '../models/profil_invest_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // --- ÉTATS DU BUDGET (Vierge par défaut) ---
  double budgetEstime = 0.0;
  double budgetReel = 0.0;
  int jourDebutMois = 1;
  int? dernierMoisTraite;

  List<Depense> depenses = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirebase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifierChangementDeMoisAutomatique();
    });
  }

  // --- TRI AUTOMATIQUE DU PLUS ÉLEVÉ AU MOINS ÉLEVÉ ---
  void _trierDepenses() {
    depenses.sort((a, b) => b.montant.compareTo(a.montant));
  }

  Future<void> _loadDataFromFirebase() async {
    final data = await _firestoreService.loadUserData();
    if (data != null && mounted) {
      setState(() {
        budgetEstime = data.budgetEstime;
        budgetReel = data.budgetReel;
        jourDebutMois = data.jourDebutMois;
        depenses = data.depenses;
        _trierDepenses();
      });
    }
  }

  Future<void> _syncWithFirebase() async {
    _trierDepenses();
    final currentData = await _firestoreService.loadUserData();
    final dataToSave = UserFinancialData(
      budgetEstime: budgetEstime,
      budgetReel: budgetReel,
      jourDebutMois: jourDebutMois,
      depenses: depenses,
      profil: currentData?.profil ?? ProfilInvest(),
      etablissements: currentData?.etablissements ?? [],
    );
    await _firestoreService.saveUserData(dataToSave);
  }

  // --- CALCULS FINANCIERS ---
  double get totalActif => depenses
      .where((d) => d.isActive)
      .fold(0.0, (sum, d) => sum + d.montant);

  double get totalPayeActif => depenses
      .where((d) => d.isActive && d.isCochee)
      .fold(0.0, (sum, d) => sum + d.montant);

  double get resteEstime => budgetEstime - totalActif;
  double get solde => budgetReel - totalPayeActif;
  double get soldeFinMois => budgetReel - totalActif;

  void _verifierChangementDeMoisAutomatique() {
    final now = DateTime.now();
    int moisActuel = now.month;
    if (now.day < jourDebutMois) {
      moisActuel = now.month == 1 ? 12 : now.month - 1;
    }

    if (dernierMoisTraite != null && dernierMoisTraite != moisActuel) {
      _executerChangementMoisAutomatique();
    }
    dernierMoisTraite = moisActuel;
  }

  void _executerChangementMoisAutomatique() {
    setState(() {
      depenses.removeWhere((d) => !d.isRecurrente);
      for (var d in depenses) {
        d.isCochee = false;
        d.isActive = true;
      }
      _trierDepenses();
    });
    _syncWithFirebase();
    _showSettingsDialog(isAutomaticNewMonth: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER LUXE KAPI AVEC DÉGRADÉ BLEU ROI -> VIOLET AMÉTHYSTE VIBRANT
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1D4ED8), // Bleu Roi éclatant
                    Color(0xFF4F46E5), // Indigo vibrant
                    Color(0xFF7C3AED), // Violet Améthyste
                    Color(0xFF9333EA), // Violet Kapi
                  ],
                  stops: [0.0, 0.35, 0.70, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(top: 28, left: 18, right: 18, bottom: 20),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💰 Kapi Budget',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('Gestion financière mensuelle',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
                              tooltip: 'Se Déconnecter',
                              onPressed: () => _authService.signOut(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                              tooltip: 'Paramètres du Budget',
                              onPressed: () => _showSettingsDialog(),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTheoryCard(),
                    const SizedBox(height: 12),
                    _buildRealStateCard(),
                  ],
                ),
              ),
            ),
          ),

          // 2. LISTE DES DÉPENSES
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: depenses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            const Text('Aucune dépense ce mois-ci', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(height: 6),
                            const Text('Appuie sur le bouton + pour en ajouter une', style: TextStyle(color: Colors.white30, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Dépenses du mois',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
                                Text('Prévues : ${totalActif.toStringAsFixed(2)} €',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                              ],
                            ),
                          );
                        }
                        final d = depenses[index - 1];
                        return _buildDepenseCard(d);
                      },
                      childCount: depenses.length + 1,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDepenseDialog,
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Dépense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildTheoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('PLANIFICATION DU MOIS',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubStat('Budget Estimé (Revenus)', '${budgetEstime.toStringAsFixed(2)} €', Colors.white),
              _buildSubStat('Reste Estimé (Théorique)', '${resteEstime.toStringAsFixed(2)} €',
                  resteEstime < 0 ? const Color(0xFFFCA5A5) : const Color(0xFF34D399), isMain: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealStateCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: Color(0xFF38BDF8), size: 17),
              SizedBox(width: 6),
              Text('MON COMPTE BANCAIRE',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubStat('Départ (Réel)', '${budgetReel.toStringAsFixed(2)} €', Colors.white),
              _buildSubStat('Solde Actuel', '${solde.toStringAsFixed(2)} €', Colors.white),
              _buildSubStat('Solde Fin de Mois', '${soldeFinMois.toStringAsFixed(2)} €',
                  soldeFinMois < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), isMain: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value, Color color, {bool isMain = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: isMain ? 15 : 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- CARTE DÉPENSE AVEC ÉTIQUETTE STATIQUE ---
  Widget _buildDepenseCard(Depense d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: d.isActive ? const Color(0xFF131B2E) : const Color(0xFF0D1322),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.isActive ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: const Color(0xFF2563EB).withOpacity(0.2),
          highlightColor: const Color(0xFF38BDF8).withOpacity(0.1),
          // APPUI LONG : MODIFIER, INCLURE/EXCLURE OU SUPPRIMER
          onLongPress: () => _showExpenseActionMenu(d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 1. COCHE DE PAIEMENT
                InkWell(
                  onTap: d.isActive
                      ? () {
                          setState(() => d.isCochee = !d.isCochee);
                          _syncWithFirebase();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: !d.isActive
                          ? Colors.transparent
                          : d.isCochee
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !d.isActive
                            ? Colors.white12
                            : d.isCochee
                                ? const Color(0xFF10B981)
                                : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.isCochee ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: !d.isActive
                              ? Colors.white24
                              : d.isCochee
                                  ? const Color(0xFF34D399)
                                  : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          d.isCochee ? 'PAYÉ' : 'À PAYER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: !d.isActive
                                ? Colors.white24
                                : d.isCochee
                                    ? const Color(0xFF34D399)
                                    : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. DÉTAILS DE LA DÉPENSE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nom,
                        style: TextStyle(
                          color: d.isActive ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: d.isCochee && d.isActive ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            d.isRecurrente ? '🔄 Mensuel' : '📍 Ponctuel',
                            style: TextStyle(color: d.isActive ? Colors.white38 : Colors.white24, fontSize: 10),
                          ),
                          const SizedBox(width: 8),

                          // 3. ÉTIQUETTE STATIQUE (NON CLIQUABLE DIRECTEMENT)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: d.isActive
                                  ? const Color(0xFF2563EB).withOpacity(0.15)
                                  : const Color(0xFFD97706).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: d.isActive
                                    ? const Color(0xFF2563EB).withOpacity(0.4)
                                    : const Color(0xFFD97706).withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              d.isActive ? '✓ Inclus' : '⊘ Hors Budget',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: d.isActive ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. MONTANT
                Text(
                  '${d.montant.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: d.isActive ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MENU D'ACTIONS SUR APPUI LONG (MODIFIER / INCLURE-EXCLURE / SUPPRIMER) ---
  void _showExpenseActionMenu(Depense d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(
                'Gérer "${d.nom}" (${d.montant.toStringAsFixed(2)} €)',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // 1. MODIFIER
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8)),
                title: const Text('Modifier la dépense', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDepenseDialog(d);
                },
              ),

              // 2. INCLURE OU EXCLURE DES CALCULS
              ListTile(
                leading: Icon(
                  d.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: d.isActive ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                ),
                title: Text(
                  d.isActive ? 'Exclure des calculs (Hors budget)' : 'Inclure dans les calculs',
                  style: TextStyle(
                    color: d.isActive ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => d.isActive = !d.isActive);
                  _syncWithFirebase();
                },
              ),

              // 3. SUPPRIMER
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                title: const Text('Supprimer définitivement', style: TextStyle(color: Color(0xFFF87171))),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => depenses.remove(d));
                  _syncWithFirebase();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FORMULAIRE DE MODIFICATION DE DÉPENSE ---
  void _showEditDepenseDialog(Depense d) {
    final nomController = TextEditingController(text: d.nom);
    final montantController = TextEditingController(text: d.montant.toStringAsFixed(2));
    bool isRecurrente = d.isRecurrente;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
          title: const Text('Modifier la Dépense', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Désignation', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: montantController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Montant (€)', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dépense Mensuelle (Récurrente)', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: isRecurrente,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setDialogState(() => isRecurrente = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () {
                final m = double.tryParse(montantController.text.replaceAll(',', '.'));
                if (nomController.text.trim().isNotEmpty && m != null && m >= 0) {
                  setState(() {
                    d.nom = nomController.text.trim();
                    d.montant = m;
                    d.isRecurrente = isRecurrente;
                  });
                  _syncWithFirebase();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- PARAMÈTRES DU BUDGET ---
  void _showSettingsDialog({bool isAutomaticNewMonth = false}) {
    final estController = TextEditingController(text: budgetEstime.toStringAsFixed(2));
    final reelController = TextEditingController(text: budgetReel.toStringAsFixed(2));
    int tempJour = jourDebutMois;

    showDialog(
      context: context,
      barrierDismissible: !isAutomaticNewMonth,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF334155))),
          title: Row(
            children: [
              Icon(isAutomaticNewMonth ? Icons.celebration : Icons.settings, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 10),
              Text(isAutomaticNewMonth ? 'Nouveau Mois ! 🎉' : 'Paramètres du Budget', style: const TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAutomaticNewMonth)
                const Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: Text('Le jour de paie est arrivé ! Le mois a été réinitialisé. Entrez vos nouveaux budgets :',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ),
              TextField(
                controller: estController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Budget Estimé (Revenus prévus) €', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reelController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Budget Réel Initial (Compte au départ) €', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 15),
              const Text('Jour de début de mois (Paie) :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              DropdownButton<int>(
                value: tempJour,
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: List.generate(31, (index) => index + 1)
                    .map((j) => DropdownMenuItem(value: j, child: Text('Chaque $j du mois')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => tempJour = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () {
                final e = double.tryParse(estController.text.replaceAll(',', '.'));
                final r = double.tryParse(reelController.text.replaceAll(',', '.'));
                if (e != null && r != null) {
                  setState(() {
                    budgetEstime = e;
                    budgetReel = r;
                    jourDebutMois = tempJour;
                  });
                  _syncWithFirebase();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- FORMULAIRE D'AJOUT DE DÉPENSE ---
  void _showAddDepenseDialog() {
    final nomController = TextEditingController();
    final montantController = TextEditingController();
    bool isRecurrente = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nouvelle Dépense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextField(
              controller: nomController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Désignation', labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: montantController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Montant (€)', labelStyle: TextStyle(color: Colors.white60)),
            ),
            StatefulBuilder(
              builder: (ctx, setModalState) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dépense Mensuelle (Récurrente)', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: isRecurrente,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setModalState(() => isRecurrente = val ?? true),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                final m = double.tryParse(montantController.text.replaceAll(',', '.'));
                if (nomController.text.trim().isNotEmpty && m != null && m >= 0) {
                  setState(() {
                    depenses.add(Depense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      nom: nomController.text.trim(),
                      montant: m,
                      isRecurrente: isRecurrente,
                    ));
                  });
                  _syncWithFirebase();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter à Kapi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}