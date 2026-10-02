import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/patrimoine_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KapiApp());
}

class KapiApp extends StatelessWidget {
  const KapiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapi Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Écouteur en direct de l'état de connexion de l'utilisateur
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF090D16),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const NavigationHub();
        }
        return const AuthScreen();
      },
    );
  }
}

class NavigationHub extends StatefulWidget {
  const NavigationHub({super.key});

  @override
  State<NavigationHub> createState() => _NavigationHubState();
}

class _NavigationHubState extends State<NavigationHub> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BudgetScreen(),
    const PatrimoineScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Investissements',
          ),
        ],
      ),
    );
  }
}