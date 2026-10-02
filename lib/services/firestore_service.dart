import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/depense_model.dart';
import '../models/etablissement_model.dart';
import '../models/profil_invest_model.dart';

class UserFinancialData {
  final double budgetEstime;
  final double budgetReel;
  final int jourDebutMois;
  final List<Depense> depenses;
  final ProfilInvest profil;
  final List<Etablissement> etablissements;

  UserFinancialData({
    required this.budgetEstime,
    required this.budgetReel,
    required this.jourDebutMois,
    required this.depenses,
    required this.profil,
    required this.etablissements,
  });

  Map<String, dynamic> toMap() {
    return {
      'budgetEstime': budgetEstime,
      'budgetReel': budgetReel,
      'jourDebutMois': jourDebutMois,
      'depenses': depenses.map((d) => {
        'id': d.id,
        'nom': d.nom,
        'montant': d.montant,
        'isRecurrente': d.isRecurrente,
        'isCochee': d.isCochee,
        'isActive': d.isActive,
      }).toList(),
      'profil': profil.toMap(),
      'etablissements': etablissements.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserFinancialData.fromMap(Map<String, dynamic> map) {
    return UserFinancialData(
      budgetEstime: (map['budgetEstime'] as num?)?.toDouble() ?? 1333.50,
      budgetReel: (map['budgetReel'] as num?)?.toDouble() ?? 1293.25,
      jourDebutMois: (map['jourDebutMois'] as num?)?.toInt() ?? 1,
      depenses: (map['depenses'] as List? ?? [])
          .map((d) => Depense(
                id: d['id'] ?? '',
                nom: d['nom'] ?? '',
                montant: (d['montant'] as num).toDouble(),
                isRecurrente: d['isRecurrente'] ?? true,
                isCochee: d['isCochee'] ?? false,
                isActive: d['isActive'] ?? true,
              ))
          .toList(),
      profil: map['profil'] != null ? ProfilInvest.fromMap(map['profil']) : ProfilInvest(),
      etablissements: (map['etablissements'] as List? ?? [])
          .map((e) => Etablissement.fromMap(e))
          .toList(),
    );
  }
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDocRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('data').doc('portfolio');
  }

  /// Récupération unique (1 seule lecture)
  Future<UserFinancialData?> loadUserData() async {
    final docRef = _userDocRef;
    if (docRef == null) return null;

    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        return UserFinancialData.fromMap(snapshot.data()!);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Sauvegarde groupée (1 seule écriture)
  Future<void> saveUserData(UserFinancialData data) async {
    final docRef = _userDocRef;
    if (docRef == null) return;

    try {
      await docRef.set(data.toMap(), SetOptions(merge: true));
    } catch (e) {
      // ignore
    }
  }
}