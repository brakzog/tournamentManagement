import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tournament_management/pages/create_tournament_page.dart';
import 'package:tournament_management/pages/login_page.dart';
import 'package:tournament_management/pages/participation_screen.dart';
import 'package:tournament_management/pages/tournament_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  HomePageState();
  int _currentIndex = 0; // Pour suivre l'onglet actuellement sélectionné.

  final List<Widget> _tabs = [
    const TournamentScreen(),
    const ParticipationScreen(),
    const LoginPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Affichez ici la page principale avec la barre de menu
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion des Tournois")),
      body: _tabs[
          _currentIndex], // Affiche l'écran correspondant à l'onglet actuellement sélectionné.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // L'onglet actuellement sélectionné.
        onTap: (int index) {
          if (index == 2) {
            // logout action
            logoutUser();
          } else {
            setState(() {
              _currentIndex =
                  index; // Met à jour l'onglet actuellement sélectionné.
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_score), // Icône pour "Mes Tournois".
            label: "Mes Tournois",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people), // Icône pour "Participations".
            label: "Participations",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.logout,
            ),
            label: "Se déconnecter",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action à effectuer lors du clic sur le bouton flottant.
          // Par exemple, naviguer vers la page de création de tournoi.
          Navigator.push(
            context,
            AnimatedCreateTournamentPageRoute(
              page: const CreateTournamentPage(),
            ),
          ).then((value) {
            setState(() {
              _currentIndex = 0;
            });
          });
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void logoutUser() async {
    FirebaseAuth.instance.signOut();
    const FlutterSecureStorage().delete(key: "userId");
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) {
          // Retournez la page de destination (par exemple, HomePage)
          return const LoginPage();
        },
      ),
    );
  }
}
