import 'package:flutter/material.dart';
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
          setState(() {
            _currentIndex =
                index; // Met à jour l'onglet actuellement sélectionné.
          });
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
        ],
      ),
    );
  }
}
