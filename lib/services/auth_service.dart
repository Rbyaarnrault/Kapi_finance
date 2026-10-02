import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream pour écouter l'état de connexion en temps réel
  Stream<User?> get userChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Inscription avec Email, Mot de Passe, Nom et Prénom
  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String nom,
    required String prenom,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Met à jour le profil Firebase Auth
        await user.updateDisplayName('$prenom $nom');

        // Enregistre les infos profil dans Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email.trim(),
          'nom': nom.trim(),
          'prenom': prenom.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null; // Succès
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'Une erreur inattendue est survenue.';
    }
  }

  /// Connexion avec Email et Mot de Passe
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Succès
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'Une erreur inattendue est survenue.';
    }
  }

  /// Réinitialisation du mot de passe par Email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Succès
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'Impossible d\'envoyer l\'email de réinitialisation.';
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cette adresse email est déjà associée à un compte.';
      case 'weak-password':
        return 'Le mot de passe doit comporter au moins 6 caractères.';
      case 'invalid-email':
        return 'L\'adresse email n\'est pas valide.';
      default:
        return 'Erreur d\'authentification : $code';
    }
  }
}