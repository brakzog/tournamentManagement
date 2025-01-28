import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tournament_management/models/tournament.dart';
import 'tournament_viewmodel.dart';

class TournamentPresenter {
  final TournamentViewmodel viewModel;

  TournamentPresenter(this.viewModel);

  Widget buildTournamentList(BuildContext context) {
    return FutureBuilder<Map<String, List<Tournament>>>(
      future: viewModel.fetchTournamentsFromFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('error_fetching'.tr()));
        } else if (snapshot.hasData) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return _buildList(viewModel, index, context);
            },
          );
        } else {
          return Center(child: Text('no_tournament_data'.tr()));
        }
      },
    );
  }

  Widget _buildList(TournamentViewmodel viewModel, int index, BuildContext context) {
    List<List<Tournament>> tournamentCategories = [
      viewModel.inProgressTournament,
      viewModel.pastTournaments,
      viewModel.cancelNotPlayedTournaments,
    ];

    List<String> categoryTitles = [
      "current_tournament".tr(),
      "past_tournaments".tr(),
      "cancelled_tournaments".tr(),
    ];

    if (tournamentCategories[index].isNotEmpty) {
      return ExpansionTile(
        title: Text(categoryTitles[index]),
        children: _retrieveListTournament(tournamentCategories[index], index == 0, context),
      );
    } else {
      return ListTile(
        title: Text(categoryTitles[index]),
      );
    }
  }

  List<Widget> _retrieveListTournament(
      List<Tournament> tournamentList, bool inProgress, BuildContext context) {
    return List.generate(tournamentList.length, (index) {
      return InkWell(
        onTap: () => viewModel.navigateToDetailPage(context, tournamentList[index], inProgress),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            tournamentList[index].name,
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      );
    });
  }
}
