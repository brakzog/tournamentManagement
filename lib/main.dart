import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament_viewmodel.dart';
import 'package:tournament_management/pages/home/home.dart';
import 'package:tournament_management/pages/home/home_viewmodel.dart';
import 'package:tournament_management/pages/login/login.dart';
import 'package:tournament_management/pages/login/login_viewmodel.dart';
import 'package:tournament_management/pages/tournament/tournament_viewmodel.dart';

import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Import easy_localization

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => TournamentViewmodel()),
                ChangeNotifierProvider(create: (_) => DetailTournamentViewModel()),

      ],
      child:    EasyLocalization(
        child: const MyApp(), 
        supportedLocales: [Locale('fr', 'FR')],
        path: 'assets/lang',
        fallbackLocale: Locale('fr', 'FR'),
      ),
    ),
  ); 
  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CheckAuth(),
      localizationsDelegates:  [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...EasyLocalization.of(context)!.delegates, // Ceci est la configuration correcte pour easy_localization
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
      return LoginPage();
    } else {
      // Si l'utilisateur est connecté, affichez la page principale
      return const HomePage();
    }
  }
}
