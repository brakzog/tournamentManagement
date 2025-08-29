import 'package:flutter/material.dart';
import 'package:tournament_management/models/tournament.dart';



import 'detail_tournament_presenter.dart';
import 'detail_tournament_viewmodel.dart';


class DetailTournament extends StatefulWidget {

  final bool inProgress; 
  final Tournament tournament;
  final String? tournamentKey;

  DetailTournament({
    required this.inProgress,
    required this.tournament,
	required this.tournamentKey, 

  });

  _DetailTournamentPageState createState() => _DetailTournamentPageState();

}

class _DetailTournamentPageState extends State<DetailTournament> with SingleTickerProviderStateMixin {
  
  late DetailTournamentPresenter presenter;
  late DetailTournamentViewModel model;

  @override
  void initState() {
    super.initState();
    model = DetailTournamentViewModel(tournament: widget.tournament);//Provider.of<DetailTournamentViewModel>(context, listen: true);
    presenter = DetailTournamentPresenter(
      widget.tournament,
      setState,
      widget.inProgress,
      model,
    );
    presenter.initTabController(this);
  }

  

  @override
  Widget build(BuildContext context) {
    return presenter.buildDetailTournament(context, tournamentKey: widget.tournamentKey);
  }
}    
