import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tournament_presenter.dart';
import 'tournament_viewmodel.dart';

class TournamentPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<TournamentViewmodel>(context, listen: true);
    final presenter = TournamentPresenter(viewModel);

    return Scaffold(
      appBar: AppBar(
        title: Text("my_tournaments".tr()),
      ),
      body: presenter.buildTournamentList(context),
    );
  }
}
