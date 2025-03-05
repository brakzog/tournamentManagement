import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'participation_presenter.dart';
import 'participation_viewmodel.dart';

class ParticipationView extends StatelessWidget{
    const ParticipationView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ParticipationViewModel>(context, listen: true);
    final presenter = ParticipationPresenter(viewModel);
    return Column(children: [
       ExpansionTile(
        title: Text("my_calendar").tr(),
        children: [presenter.buildMyCalendar(context)],
      ),
      ExpansionTile(
        title: Text("my_result").tr(),
        children: [presenter.buildMyResult(context)],
      )



      /*Text("my_calendar").tr(),
      presenter.buildMyCalendar(context),
      Container(
        margin: EdgeInsets.symmetric(vertical: 10), // Espacement vertical
        height: 1, // Épaisseur de la ligne
        width: double.infinity, // Prend toute la largeur disponible
        color: Colors.grey, // Couleur de la ligne
      ),
      Text("my_result").tr(),
      presenter.buildMyResult(context),
    */]);
  }

 
}    
