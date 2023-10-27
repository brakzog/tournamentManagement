import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CheckAuth(),
    );
  }
}

class CheckAuth extends StatelessWidget {
  const CheckAuth({super.key});

  @override
  Widget build(BuildContext context) {
    // Vérifiez si l'utilisateur est connecté
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Si l'utilisateur n'est pas connecté, affichez la page de connexion
      return const LoginPage();
    } else {
      // Si l'utilisateur est connecté, affichez la page principale
      return const HomePage();
    }
  }
}
