import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  bool isLoginMode = true; // true = Connexion, false = Inscription
  bool isPasswordObscured = true;
  bool isLoading = false;
  String? errorMessage;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    String? error;
    if (isLoginMode) {
      error = await _authService.signInWithEmail(
        email: emailController.text,
        password: passwordController.text,
      );
    } else {
      if (nomController.text.trim().isEmpty || prenomController.text.trim().isEmpty) {
        setState(() {
          errorMessage = 'Veuillez renseigner votre nom et prénom.';
          isLoading = false;
        });
        return;
      }
      error = await _authService.registerWithEmail(
        email: emailController.text,
        password: passwordController.text,
        nom: nomController.text,
        prenom: prenomController.text,
      );
    }

    if (mounted) {
      setState(() {
        errorMessage = error;
        isLoading = false;
      });
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Text('Mot de passe oublié ?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez votre adresse email pour recevoir un lien de réinitialisation :',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'votre.email@exemple.com',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF131B2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
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
            onPressed: () async {
              if (resetEmailController.text.isNotEmpty) {
                final err = await _authService.sendPasswordResetEmail(resetEmailController.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: err == null ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      content: Text(err ?? 'Lien de réinitialisation envoyé par email !'),
                    ),
                  );
                }
              }
            },
            child: const Text('Envoyer le lien', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO & TITRE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))
                    ],
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kapi Finance',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoginMode ? 'Connectez-vous à votre espace financier' : 'Créez votre compte investisseur',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // CARTE FORMULAIRE
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CHAMPS INSCRIPTION (PRÉNOM & NOM)
                      if (!isLoginMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: prenomController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Prénom', Icons.person_outline),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: nomController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Nom', Icons.badge_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // EMAIL
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Adresse email', Icons.mail_outline),
                      ),
                      const SizedBox(height: 14),

                      // MOT DE PASSE AVEC ICÔNE OEIL
                      TextField(
                        controller: passwordController,
                        obscureText: isPasswordObscured,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Mot de passe', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white38,
                              size: 20,
                            ),
                            onPressed: () => setState(() => isPasswordObscured = !isPasswordObscured),
                          ),
                        ),
                      ),

                      // MOT DE PASSE OUBLIÉ (EN MODE CONNEXION)
                      if (isLoginMode) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Mot de passe oublié ?', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                      ],

                      // MESSAGE D'ERREUR
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                          ),
                        ),
                      ],

                      // BOUTON PRINCIPAL (CONNEXION / INSCRIPTION)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isLoginMode ? 'Se Connecter' : 'Créer mon Compte',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // BASCULE CONNEXION / INSCRIPTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoginMode ? 'Pas encore de compte ?' : 'Vous avez déjà un compte ?',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLoginMode = !isLoginMode;
                          errorMessage = null;
                        });
                      },
                      child: Text(
                        isLoginMode ? 'S\'inscrire' : 'Se Connecter',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
      filled: true,
      fillColor: const Color(0xFF090D16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}