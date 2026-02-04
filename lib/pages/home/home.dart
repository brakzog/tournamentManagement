import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tournament_management/pages/create_tournament/create_tournament.dart';
import 'package:tournament_management/pages/login/login.dart';
import 'package:tournament_management/pages/participation/participation.dart';
import 'package:tournament_management/pages/tournament/tournament.dart';

import 'home_viewmodel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final state = viewModel.state;

    final pages = <Widget>[
      TournamentPage(),       // Mes tournois
      ParticipationView(),    // Mes participations
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('tournament_management'.tr(), overflow: TextOverflow.ellipsis),
        actions: [
          if (state.isLoggingOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'logout'.tr(),
              onPressed: () async {
                await viewModel.onIntent(const HomeLogoutIntent());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: state.currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: state.currentIndex,
        onTap: (index) =>
            viewModel.onIntent(HomeSelectTabIntent(index)),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events),
            label: 'my_tournaments'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: 'my_participations'.tr(), // adapte à ta clé de traduction
          ),
        ],
      ),
      floatingActionButton: state.currentIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(
              builder: (_) => CreateTournamentPage(),
            ),
          )
              .then((_) {
            // Quand on revient, on revient sur l’onglet "Mes tournois"
            viewModel.onIntent(const HomeSelectTabIntent(0));
          });
        },
        child: const Icon(Icons.add),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
