import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tournament_management/models/tournament.dart';
import 'tournament_viewmodel.dart';

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key});

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        final viewModel = context.read<TournamentViewmodel>();
        viewModel.onIntent(const StartListeningTournamentsIntent());
        _initialized = true;
      }
    });
  }

  @override
  void dispose() {
    final viewModel = context.read<TournamentViewmodel>();
    viewModel.onIntent(const StopListeningTournamentsIntent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TournamentViewmodel>();
    final state = viewModel.state;

    Widget body;

    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.errorMessage != null) {
      body = Center(child: Text('error_fetching'.tr()));
    } else {
      final hasAny = state.inProgress.isNotEmpty ||
          state.past.isNotEmpty ||
          state.cancel.isNotEmpty;

      if (!hasAny) {
        body = Center(child: Text('no_tournament_data'.tr()));
      } else {
        body = ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return _buildCategoryTile(state, viewModel, index, context);
          },
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("my_tournaments".tr()),
      ),
      body: body,
    );
  }

  Widget _buildCategoryTile(
      TournamentState state,
      TournamentViewmodel viewModel,
      int index,
      BuildContext context,
      ) {
    final List<List<Tournament>> tournamentCategories = [
      state.inProgress,
      state.past,
      state.cancel,
    ];

    final List<String> categoryTitles = [
      "current_tournament".tr(),
      "past_tournaments".tr(),
      "cancelled_tournaments".tr(),
    ];

    final tournaments = tournamentCategories[index];

    if (tournaments.isNotEmpty) {
      return ExpansionTile(
        title: Text(categoryTitles[index]),
        children: _buildTournamentTiles(
          viewModel,
          tournaments,
          index == 0,
          context,
        ),
      );
    } else {
      return ListTile(
        title: Text(categoryTitles[index]),
      );
    }
  }

  List<Widget> _buildTournamentTiles(
      TournamentViewmodel viewModel,
      List<Tournament> tournamentList,
      bool inProgress,
      BuildContext context,
      ) {
    return List.generate(tournamentList.length, (index) {
      final tournament = tournamentList[index];

      return InkWell(
        onTap: () => viewModel.navigateToDetailPage(
          context,
          tournament,
          inProgress,
        ),
        child: ListTile(
          title: Text(tournament.name),
        ),
      );
    });
  }
}
