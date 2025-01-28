import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament.dart';
import 'package:tournament_management/pages/login/login.dart';
import 'package:tournament_management/pages/tournament/tournament.dart';

import 'home_presenter.dart';
import 'home_viewmodel.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HomeViewModel>(context, listen: true);
    final presenter = HomePresenter(viewModel);

    final List<Widget> tabs = [
      TournamentPage(),
     // ParticipationScreen(),
      LoginPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("tournament_management").tr()),
      body: tabs[viewModel.currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: viewModel.currentIndex,
        onTap: (index) async {
          if (index == 2) {
            // Déconnexion
            await presenter.onLogoutTapped();
            Navigator.of(context).popUntil((route) => route.isFirst);  // Ajout pour mieux gérer la navigation
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          } else {
            // Met à jour l'onglet sélectionné
            presenter.onTabSelected(index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_score),
            label: "my_tournaments".tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "participation".tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: "logout".tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            AnimatedCreateTournamentPageRoute(
              page: const CreateTournamentPage(),
            ),
          ).then((value) {
            presenter.onTabSelected(0); // Retourne à l’onglet "Mes Tournois"
          });
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
