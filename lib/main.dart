// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

// == Tes imports d'app ==
import 'package:tournament_management/pages/home/home.dart';
import 'package:tournament_management/pages/login/login.dart';

// ViewModels (adapte les chemins si besoin)
import 'package:tournament_management/pages/home/home_viewmodel.dart';
import 'package:tournament_management/pages/login/login_viewmodel.dart';
import 'package:tournament_management/pages/tournament/tournament_viewmodel.dart';
import 'package:tournament_management/pages/participation/participation_viewmodel.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_viewmodel.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament_viewmodel.dart';

import 'firebase_options.dart'; // si tu utilises `flutterfire configure`



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    EasyLocalization(
	  supportedLocales: [Locale('fr', 'FR')],
      path: 'assets/lang', 
      fallbackLocale: const Locale('fr', 'FR'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LoginViewModel()),
		      ChangeNotifierProvider(create: (_) => HomeViewModel()),
          ChangeNotifierProvider(create: (_) => TournamentViewmodel()),
          ChangeNotifierProvider(create: (_) => CreateTournamentViewModel()),
          ChangeNotifierProvider(create: (_) => ParticipationViewModel()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const Root(), // switch Login/Home selon l’auth en temps réel
    );
  }
}



/// Écran racine : écoute authStateChanges() pour basculer automatiquement
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('auth_error'.tr())),
          );
        }
        final user = snap.data;
        return user == null ? LoginPage() : HomePage();
      },
    );
  }
}

/// Splash minimal traduit le temps d’initialiser
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'loading'.tr(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('loading'.tr()),
            ],
          ),
        ),
      ),
    );
  }
}

