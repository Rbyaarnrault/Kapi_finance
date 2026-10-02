import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/actif_model.dart';
import '../models/enveloppe_model.dart';
import '../models/etablissement_model.dart';
import '../models/profil_invest_model.dart';
import '../services/yahoo_finance_service.dart';
import '../services/firestore_service.dart';

class PatrimoineScreen extends StatefulWidget {
  const PatrimoineScreen({super.key});

  @override
  State<PatrimoineScreen> createState() => _PatrimoineScreenState();
}

class _PatrimoineScreenState extends State<PatrimoineScreen> {
  final YahooFinanceService _yahooService = YahooFinanceService();
  final FirestoreService _firestoreService = FirestoreService();

  ProfilInvest profil = ProfilInvest(
    mode: ModeInvestissement.profil1Bankroll,
    budgetMensuelGlobal: 0.0,
  );

  List<FlSpot> globalSpots = [];
  bool isLoadingGlobalGraph = false;

  // Initialement vierge pour chaque nouvel utilisateur
  List<Etablissement> etablissements = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirebase();
  }

  Future<void> _loadDataFromFirebase() async {
    final data = await _firestoreService.loadUserData();
    if (data != null && mounted) {
      setState(() {
        profil = data.profil;
        etablissements = data.etablissements;
      });
    }
    _loadGlobalGraph();
  }

  Future<void> _syncWithFirebase() async {
    final currentData = await _firestoreService.loadUserData();
    final dataToSave = UserFinancialData(
      budgetEstime: currentData?.budgetEstime ?? 0.0,
      budgetReel: currentData?.budgetReel ?? 0.0,
      jourDebutMois: currentData?.jourDebutMois ?? 1,
      depenses: currentData?.depenses ?? [],
      profil: profil,
      etablissements: etablissements,
    );
    await _firestoreService.saveUserData(dataToSave);
  }

  double get patrimoineTotalGlobal =>
      etablissements.fold(0.0, (sum, etab) => sum + etab.patrimoineTotalEtablissement);

  double get plusValueGlobaleEuro {
    double pv = 0.0;
    for (var etab in etablissements) {
      for (var env in etab.enveloppes) {
        for (var actif in env.actifs) {
          pv += actif.plusValueLatenteEuro;
        }
      }
    }
    return pv;
  }

  double get plusValueGlobalePourcent {
    double totalPru = 0.0;
    for (var etab in etablissements) {
      for (var env in etab.enveloppes) {
        for (var actif in env.actifs) {
          totalPru += (actif.pru * actif.nombreParts);
        }
      }
    }
    return totalPru > 0 ? (plusValueGlobaleEuro / totalPru) * 100 : 0.0;
  }

  Future<void> _loadGlobalGraph({bool forceRefresh = false}) async {
    setState(() => isLoadingGlobalGraph = true);

    List<Actif> allActifs = [];
    for (var etab in etablissements) {
      for (var env in etab.enveloppes) {
        allActifs.addAll(env.actifs);
      }
    }

    if (allActifs.isEmpty) {
      setState(() {
        globalSpots = [];
        isLoadingGlobalGraph = false;
      });
      return;
    }

    Map<double, double> aggregatedCurve = {};
    for (var actif in allActifs) {
      final spots = await _yahooService.getHistoricalPoints(actif.ticker, forceRefresh: forceRefresh);
      for (var spot in spots) {
        aggregatedCurve[spot.x] = (aggregatedCurve[spot.x] ?? 0.0) + (spot.y * actif.nombreParts);
      }
    }

    final sortedSpots = aggregatedCurve.entries
        .map((e) => FlSpot(e.key, e.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    setState(() {
      globalSpots = sortedSpots;
      isLoadingGlobalGraph = false;
    });
  }

  Widget _buildInteractiveChart(List<FlSpot> spots, {double height = 150, Color lineColor = const Color(0xFF38BDF8)}) {
    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Aucune donnée de cours disponible', style: TextStyle(color: Colors.white30, fontSize: 11))),
      );
    }

    double minX = spots.first.x;
    double maxX = spots.last.x;
    double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    double yMargin = (maxY - minY) == 0 ? 10.0 : (maxY - minY) * 0.1;
    minY = (minY - yMargin).clamp(0.0, double.infinity);
    maxY = maxY + yMargin;

    return Container(
      height: height,
      padding: const EdgeInsets.only(top: 10, right: 10, left: 0, bottom: 4),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (val, meta) {
                  return Text(
                    '${val.toStringAsFixed(2)}€',
                    style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (maxX - minX) / 3 > 0 ? (maxX - minX) / 3 : 1,
                getTitlesWidget: (val, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(val.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              tooltipBorder: const BorderSide(color: Color(0xFF38BDF8), width: 1),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                  final formattedDate =
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(2)} €\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    children: [
                      TextSpan(
                        text: formattedDate,
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.normal),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER & SYNTHÈSE
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF090D16)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.only(top: 26, left: 16, right: 16, bottom: 16),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.show_chart, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kapi Invest', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                Text('Portfolio & Wealth Management', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                              tooltip: 'Actualiser les cours',
                              onPressed: () => _loadGlobalGraph(forceRefresh: true),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                                tooltip: 'Paramètres Investissement',
                                onPressed: _showInvestSettingsDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PATRIMOINE CONSOLIDÉ',
                                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: Text(
                                  '${plusValueGlobaleEuro >= 0 ? '+' : ''}${plusValueGlobaleEuro.toStringAsFixed(2)} € (${plusValueGlobalePourcent.toStringAsFixed(2)}%)',
                                  style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${patrimoineTotalGlobal.toStringAsFixed(2)} €',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 12),

                          isLoadingGlobalGraph
                              ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))))
                              : _buildInteractiveChart(globalSpots, height: 150, lineColor: const Color(0xFF38BDF8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. LISTE DES ÉTABLISSEMENTS
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: etablissements.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance_outlined, color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            const Text('Aucun établissement configuré', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                              onPressed: _showInvestSettingsDialog,
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              label: const Text('Ajouter un compte via les paramètres', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildEtablissementTile(etablissements[index]),
                      childCount: etablissements.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtablissementTile(Etablissement etab) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          iconColor: const Color(0xFF38BDF8),
          collapsedIconColor: Colors.white54,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance, color: Color(0xFF38BDF8), size: 20),
          ),
          title: Text(etab.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${etab.patrimoineTotalEtablissement.toStringAsFixed(2)} €',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more, color: Colors.white54, size: 22),
            ],
          ),
          children: [
            Container(height: 1, color: const Color(0xFF1E293B)),
            FutureBuilder<List<FlSpot>>(
              future: _calculateEtablissementCurve(etab),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))));
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Performance chez ${etab.nom}', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      _buildInteractiveChart(snapshot.data!, height: 110, lineColor: const Color(0xFF818CF8)),
                    ],
                  ),
                );
              },
            ),
            ...etab.enveloppes.map((env) => _buildEnveloppeTile(etab, env)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEnveloppeTile(Etablissement etab, Enveloppe env) {
    Color badgeColor = env.type == TypeEnveloppe.pea
        ? const Color(0xFF7C3AED)
        : env.type == TypeEnveloppe.cto
            ? const Color(0xFF0284C7)
            : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          iconColor: const Color(0xFF38BDF8),
          collapsedIconColor: Colors.white38,
          title: Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(env.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(env.type.name.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${env.valeurTotaleEnveloppe.toStringAsFixed(2)} €',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, color: Colors.white38, size: 20),
            ],
          ),
          children: [
            if (profil.mode == ModeInvestissement.profil1Bankroll)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('💵 Poche Cash / Intérêts', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    Text('${env.pocheCash.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),

            ...env.actifs.map((actif) => _buildActifTile(env, actif)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: InkWell(
                onTap: () => _dialogSearchYahoo(env),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 6),
                      Text('Ajouter un Actif (Recherche Yahoo)',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NIVEAU 3 : SANS LE TICKER DANS LA SYNTHÈSE ---
  Widget _buildActifTile(Enveloppe env, Actif a) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: const Color(0xFF38BDF8),
        collapsedIconColor: Colors.white38,
        title: Text(a.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${a.nombreParts.toStringAsFixed(0)} part(s) • PRU: ${a.pru.toStringAsFixed(2)} € • Cours: ${a.prixActuel.toStringAsFixed(2)} €',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${a.valeurTotale.toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(
                  '${a.plusValueLatenteEuro >= 0 ? '+' : ''}${a.plusValueLatenteEuro.toStringAsFixed(2)} €',
                  style: TextStyle(
                      color: a.plusValueLatenteEuro >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: const Color(0xFF2563EB),
                minimumSize: const Size(55, 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showTransactionDialog(env, a),
              child: const Text('Gérer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        children: [
          FutureBuilder<List<FlSpot>>(
            future: _yahooService.getHistoricalPoints(a.ticker),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))));
              }
              return Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                child: _buildInteractiveChart(snapshot.data!, height: 110, lineColor: const Color(0xFF34D399)),
              );
            },
          )
        ],
      ),
    );
  }

  Future<List<FlSpot>> _calculateEtablissementCurve(Etablissement etab) async {
    List<Actif> actifs = [];
    for (var env in etab.enveloppes) {
      actifs.addAll(env.actifs);
    }
    if (actifs.isEmpty) return [];

    Map<double, double> curve = {};
    for (var a in actifs) {
      final spots = await _yahooService.getHistoricalPoints(a.ticker);
      for (var s in spots) {
        curve[s.x] = (curve[s.x] ?? 0.0) + (s.y * a.nombreParts);
      }
    }
    final sorted = curve.entries.map((e) => FlSpot(e.key, e.value)).toList()..sort((a, b) => a.x.compareTo(b.x));
    return sorted;
  }

  void _showTransactionDialog(Enveloppe env, Actif actif) {
    final partsController = TextEditingController(text: '1');
    final prixExecController = TextEditingController(text: actif.prixActuel.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        title: Text('Transaction : ${actif.nom}', style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: partsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nombre de parts', labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: prixExecController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Prix d\'exécution (€)', labelStyle: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final p = double.tryParse(partsController.text) ?? 0;
              final pr = double.tryParse(prixExecController.text.replaceAll(',', '.')) ?? 0;
              if (p > 0 && p <= actif.nombreParts) {
                setState(() {
                  actif.nombreParts -= p;
                  if (profil.mode == ModeInvestissement.profil1Bankroll) actif.bankrollActuelle += (p * pr);
                });
                _syncWithFirebase();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Vendre', style: TextStyle(color: Color(0xFFF87171))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final p = double.tryParse(partsController.text) ?? 0;
              final pr = double.tryParse(prixExecController.text.replaceAll(',', '.')) ?? 0;
              if (p > 0 && pr > 0) {
                setState(() {
                  double totalAncien = actif.nombreParts * actif.pru;
                  double totalNouveau = p * pr;
                  actif.nombreParts += p;
                  actif.pru = (totalAncien + totalNouveau) / actif.nombreParts;
                  actif.prixActuel = pr;
                  if (profil.mode == ModeInvestissement.profil1Bankroll) {
                    actif.bankrollActuelle = (actif.bankrollActuelle - (p * pr)).clamp(0, double.infinity);
                  }
                });
                _syncWithFirebase();
                _loadGlobalGraph();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Acheter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- PARAMÈTRES GLOBAUX AVEC NOMS D'ACTIFS CLAIRS ---
  void _showInvestSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<Actif> allActifs = [];
          for (var etab in etablissements) {
            for (var env in etab.enveloppes) {
              allActifs.addAll(env.actifs);
            }
          }
          double totalPercent = allActifs.fold(0.0, (s, a) => s + a.pourcentageCible);
          bool isPercentValid = allActifs.isEmpty || (totalPercent - 100.0).abs() < 0.1;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: const EdgeInsets.all(18),
            child: ListView(
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF38BDF8)),
                    SizedBox(width: 8),
                    Text('Configuration Investissement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Profil de Gestion Stratégique :', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () => setSheetState(() => profil.mode = ModeInvestissement.profil1Bankroll),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: profil.mode == ModeInvestissement.profil1Bankroll ? const Color(0xFF1E293B) : const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: profil.mode == ModeInvestissement.profil1Bankroll ? const Color(0xFF38BDF8) : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('🔹 Profil 1 : Budget Fixe (Bankrolls)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            if (profil.mode == ModeInvestissement.profil1Bankroll)
                              const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Vous investissez un montant fixe chaque mois. Vos fonds s\'accumulent dans des bankrolls par actif et Kapi déclenche un signal dès qu\'une part entière peut être achetée.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () => setSheetState(() => profil.mode = ModeInvestissement.profil2PartsReelles),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: profil.mode == ModeInvestissement.profil2PartsReelles ? const Color(0xFF1E293B) : const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: profil.mode == ModeInvestissement.profil2PartsReelles ? const Color(0xFF38BDF8) : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('🔸 Profil 2 : Achat en Parts Réelles (DCA Flexible)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            if (profil.mode == ModeInvestissement.profil2PartsReelles)
                              const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Vous ciblez un nombre de parts fixes. Votre effort d\'épargne mensuel s\'adapte en temps réel aux cours des actifs.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(color: Color(0xFF1E293B)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gestion des Comptes & Actifs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    TextButton.icon(
                      onPressed: () => _dialogAddEtablissement(setSheetState),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                      label: const Text('Banque', style: TextStyle(color: Color(0xFF38BDF8))),
                    ),
                  ],
                ),

                ...etablissements.map((etab) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(etab.nom, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.white60),
                                  tooltip: 'Renommer la banque',
                                  onPressed: () => _dialogRenameEtablissement(etab, setSheetState),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
                                  tooltip: 'Supprimer la banque',
                                  onPressed: () {
                                    setSheetState(() => etablissements.remove(etab));
                                    setState(() {});
                                    _syncWithFirebase();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_card, size: 18, color: Color(0xFF38BDF8)),
                                  tooltip: 'Ajouter un compte/livret',
                                  onPressed: () => _dialogAddEnveloppe(etab, setSheetState),
                                ),
                              ],
                            ),
                          ],
                        ),

                        ...etab.enveloppes.map((env) => Container(
                              margin: const EdgeInsets.only(left: 4, top: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF090D16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('• ${env.nom} (${env.type.name.toUpperCase()})',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 14, color: Colors.white60),
                                            tooltip: 'Renommer le compte',
                                            onPressed: () => _dialogRenameEnveloppe(env, setSheetState),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.attach_money, size: 16, color: Color(0xFF34D399)),
                                            tooltip: 'Modifier le cash',
                                            onPressed: () => _dialogManageCash(env, setSheetState),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFF87171)),
                                            tooltip: 'Supprimer le compte',
                                            onPressed: () {
                                              setSheetState(() => etab.enveloppes.remove(env));
                                              setState(() {});
                                              _syncWithFirebase();
                                            },
                                          ),
                                        ],
                                      )
                                    ],
                                  ),

                                  // NOM DE L'ACTIF AFFICHÉ SUR LES SLIDERS
                                  ...env.actifs.map((a) => Padding(
                                        padding: const EdgeInsets.only(left: 12, top: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text('${a.nom} (${a.nombreParts.toStringAsFixed(0)} parts @ ${a.pru.toStringAsFixed(2)}€)',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, size: 14, color: Color(0xFF38BDF8)),
                                                      tooltip: 'Modifier PRU / Parts',
                                                      onPressed: () => _dialogEditExistingActif(a, setSheetState),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.close, size: 14, color: Color(0xFFF87171)),
                                                      tooltip: 'Supprimer l\'actif',
                                                      onPressed: () {
                                                        setSheetState(() => env.actifs.remove(a));
                                                        setState(() {});
                                                        _syncWithFirebase();
                                                      },
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                            if (profil.mode == ModeInvestissement.profil1Bankroll) ...[
                                              Text('Allocation pour ${a.nom} : ${a.pourcentageCible.toStringAsFixed(0)}% du budget',
                                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10)),
                                              Slider(
                                                value: a.pourcentageCible,
                                                min: 0,
                                                max: 100,
                                                divisions: 20,
                                                activeColor: const Color(0xFF38BDF8),
                                                onChanged: (v) => setSheetState(() => a.pourcentageCible = v),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ))
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 15),

                if (profil.mode == ModeInvestissement.profil1Bankroll && allActifs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPercentValid ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPercentValid
                          ? '✅ Allocation valide (Total : 100 %)'
                          : '⚠️ Attention : La somme des allocations doit faire 100 % (Actuel : ${totalPercent.toStringAsFixed(0)} %)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),

                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPercentValid || profil.mode == ModeInvestissement.profil2PartsReelles
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade800,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isPercentValid || profil.mode == ModeInvestissement.profil2PartsReelles
                      ? () {
                          setState(() {});
                          _syncWithFirebase();
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text('Enregistrer les Paramètres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _dialogSearchYahoo(Enveloppe env) {
    final searchController = TextEditingController();
    List<YahooSearchResult> results = [];
    bool isSearching = false;
    String searchType = 'Nom';
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void performSearch(String query) async {
            if (query.trim().isEmpty) {
              setDialogState(() => results = []);
              return;
            }
            setDialogState(() => isSearching = true);
            final r = await _yahooService.searchAssets(query);
            setDialogState(() {
              results = r;
              isSearching = false;
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
            title: const Text('Recherche d\'Actif (Yahoo Finance)', style: TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Nom', 'Ticker', 'ISIN'].map((type) {
                      final isSelected = searchType == type;
                      return ChoiceChip(
                        label: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 11)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFF131B2E),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => searchType = type);
                            performSearch(searchController.text);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (text) {
                      if (debounce?.isActive ?? false) debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 400), () {
                        performSearch(text);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: searchType == 'Nom'
                          ? 'Ex: Nasdaq, Bitcoin, Total...'
                          : searchType == 'Ticker'
                              ? 'Ex: PUST.PA, AAPL, BTC-EUR...'
                              : 'Ex: FR0011871128...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF131B2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isSearching) const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),

                  Expanded(
                    child: results.isEmpty && !isSearching
                        ? Center(
                            child: Text(
                              searchController.text.isEmpty ? 'Tapez une lettre pour chercher...' : 'Aucun résultat trouvé',
                              style: const TextStyle(color: Colors.white30, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (ctx, i) {
                              final item = results[i];
                              return ListTile(
                                dense: true,
                                title: Text(item.shortname, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                subtitle: Text('${item.symbol} • ${item.exchange} (${item.currency})', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _dialogConfigureNewActif(env, item);
                                },
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _dialogConfigureNewActif(Enveloppe env, YahooSearchResult item) {
    final nameController = TextEditingController(text: item.shortname);
    final partsController = TextEditingController(text: '1');
    final pruController = TextEditingController(text: '50.00');
    final percentController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        title: Text('Ajouter : ${item.symbol}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nom affiché', labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: partsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Parts déjà possédées', labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: pruController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Prix de Revient Unitaire (PRU en €)', labelStyle: TextStyle(color: Colors.white60)),
            ),
            if (profil.mode == ModeInvestissement.profil1Bankroll)
              TextField(
                controller: percentController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Allocation cible (% du budget)', labelStyle: TextStyle(color: Colors.white60)),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              final p = double.tryParse(partsController.text) ?? 0;
              final pr = double.tryParse(pruController.text.replaceAll(',', '.')) ?? 0;
              final pc = double.tryParse(percentController.text) ?? 0;

              setState(() {
                env.actifs.add(Actif(
                  id: DateTime.now().toString(),
                  nom: nameController.text.trim().isNotEmpty ? nameController.text.trim() : item.shortname,
                  ticker: item.symbol,
                  devise: item.currency,
                  bourse: item.exchange,
                  nombreParts: p,
                  pru: pr > 0 ? pr : 50.0,
                  prixActuel: pr > 0 ? pr : 50.0,
                  pourcentageCible: pc,
                ));
              });
              _syncWithFirebase();
              _loadGlobalGraph();
              Navigator.pop(ctx);
            },
            child: const Text('Confirmer l\'ajout', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _dialogEditExistingActif(Actif a, StateSetter setSheetState) {
    final nameController = TextEditingController(text: a.nom);
    final partsController = TextEditingController(text: a.nombreParts.toString());
    final pruController = TextEditingController(text: a.pru.toStringAsFixed(2));
    final prixController = TextEditingController(text: a.prixActuel.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        title: Text('Modifier : ${a.ticker}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom de l\'actif', labelStyle: TextStyle(color: Colors.white60))),
            TextField(controller: partsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre de parts', labelStyle: TextStyle(color: Colors.white60))),
            TextField(controller: pruController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Prix de Revient (PRU en €)', labelStyle: TextStyle(color: Colors.white60))),
            TextField(controller: prixController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Cours actuel (€)', labelStyle: TextStyle(color: Colors.white60))),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              final p = double.tryParse(partsController.text) ?? a.nombreParts;
              final pr = double.tryParse(pruController.text.replaceAll(',', '.')) ?? a.pru;
              final px = double.tryParse(prixController.text.replaceAll(',', '.')) ?? a.prixActuel;

              setSheetState(() {
                if (nameController.text.trim().isNotEmpty) a.nom = nameController.text.trim();
                a.nombreParts = p;
                a.pru = pr;
                a.prixActuel = px;
              });
              setState(() {});
              _syncWithFirebase();
              _loadGlobalGraph();
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _dialogAddEtablissement(StateSetter setSheetState) {
    final nomController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Nouvel Établissement', style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: nomController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Ex: Trade Republic, Boursorama...', hintStyle: TextStyle(color: Colors.white38))),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (nomController.text.isNotEmpty) {
                setSheetState(() {
                  etablissements.add(Etablissement(id: DateTime.now().toString(), nom: nomController.text));
                });
                setState(() {});
                _syncWithFirebase();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter'),
          )
        ],
      ),
    );
  }

  void _dialogRenameEtablissement(Etablissement etab, StateSetter setSheetState) {
    final nameController = TextEditingController(text: etab.nom);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Renommer l\'établissement', style: TextStyle(color: Colors.white)),
        content: TextField(controller: nameController, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setSheetState(() => etab.nom = nameController.text);
                setState(() {});
                _syncWithFirebase();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
  }

  void _dialogRenameEnveloppe(Enveloppe env, StateSetter setSheetState) {
    final nameController = TextEditingController(text: env.nom);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Renommer le compte', style: TextStyle(color: Colors.white)),
        content: TextField(controller: nameController, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setSheetState(() => env.nom = nameController.text);
                setState(() {});
                _syncWithFirebase();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
  }

  void _dialogAddEnveloppe(Etablissement etab, StateSetter setSheetState) {
    final nomController = TextEditingController();
    TypeEnveloppe type = TypeEnveloppe.pea;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text('Nouveau Compte (${etab.nom})', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nomController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Nom du compte', hintStyle: TextStyle(color: Colors.white38))),
              const SizedBox(height: 10),
              DropdownButton<TypeEnveloppe>(
                value: type,
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: TypeEnveloppe.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                    .toList(),
                onChanged: (v) => setDialogState(() => type = v!),
              )
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (nomController.text.isNotEmpty) {
                  setSheetState(() {
                    etab.enveloppes.add(Enveloppe(id: DateTime.now().toString(), nom: nomController.text, type: type));
                  });
                  setState(() {});
                  _syncWithFirebase();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Créer'),
            )
          ],
        ),
      ),
    );
  }

  void _dialogManageCash(Enveloppe env, StateSetter setSheetState) {
    final cashController = TextEditingController(text: env.pocheCash.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text('Poche Espèces (${env.nom})', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: cashController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Montant disponible (€)', labelStyle: TextStyle(color: Colors.white60)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final c = double.tryParse(cashController.text.replaceAll(',', '.'));
              if (c != null) {
                setSheetState(() => env.pocheCash = c);
                setState(() {});
                _syncWithFirebase();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
  }
}