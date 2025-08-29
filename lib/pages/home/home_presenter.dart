import 'home_viewmodel.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:tournament_management/data/repositories/tournament_repository.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament.dart';





class HomePresenter {
  final HomeViewModel viewModel;

  HomePresenter(this.viewModel);

  void onTabSelected(int index) {
    viewModel.updateTabIndex(index);
  }

  Future<void> onLogoutTapped() async {
    await viewModel.logout();
  }
  
   Widget buildTournamentList(BuildContext context) {
   final repo = Provider.of<TournamentRepository>(context, listen: false);
    return StreamBuilder<List<Tournament>>(
      stream: repo.watchTournaments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('error_fetching'.tr()));
        }
        final items = snap.data ?? const <Tournament>[];
        if (items.isEmpty) {
          return Center(child: Text('no_tournament'.tr())); // ajoute la clé si besoin
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = items[i];
            final dateStr = t.tournamentDate.start; // compatible avec ton modèle
            return ListTile(
              title: Text(t.name),
              subtitle: Text('${t.location} • $dateStr'),
              onTap: () {
				Navigator.of(context).push(
					MaterialPageRoute(
						builder: (_) => DetailTournament(
							tournament: t,
							inProgress: true,
							tournamentKey: null,
						),
					),
				);
			  },
			);
		  },
		);

	}, );
}
}
