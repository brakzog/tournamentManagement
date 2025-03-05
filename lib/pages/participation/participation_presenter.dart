import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/participation_model.dart';

import 'participation_viewmodel.dart';

class ParticipationPresenter {
  final ParticipationViewModel viewModel;

  ParticipationPresenter(this.viewModel);


  Widget buildMyCalendar(BuildContext context) {
    return FutureBuilder(future: viewModel.fetchCalendarFromFirebase(false), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return Center(child: Text('error_fetching'.tr()));
      } else if (snapshot.hasData) {
        if(snapshot.data!.isEmpty) 
          return Padding(
            padding: const EdgeInsets.all(30.0),
            child: Center(child: Text('no_calendar_data'.tr())),
          );
        else
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) { 
                return _buildItem(snapshot.data, index, context);
            },
          );
        } else {
        return Center(child: Text('no_calendar_data'.tr()));
      }
    });
  }


  Widget buildMyResult(BuildContext ) {
    return FutureBuilder(future: viewModel.fetchCalendarFromFirebase(true), builder: (context, snapshot) {
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
            return _buildItem(snapshot.data, index, context);
          },
        );
      } else {
        return Center(child: Text('no_result'.tr()));
      }
    });

  }

    
  

  Widget _buildItem(List<ParticipationModel>? list, int index, BuildContext context) {

    var opname = list![index].opposant;    
    String date = list[index].date;
    String location = list[index].location;
    String score = list[index].score;
    return Column(children: [
       Container(
  margin: EdgeInsets.symmetric(vertical: 10), // Espacement vertical
  height: 1, // Épaisseur de la ligne
  width: double.infinity, // Prend toute la largeur disponible
  color: Colors.grey, // Couleur de la ligne
)

,
      Text('opponent').tr(args: [opname]),
      Text('match_date').tr(args: [date]),
      Text('location').tr(args: [location]),
      if(score.isNotEmpty) Text('score').tr(args:[score]),

     
    ],);
  }
}  
