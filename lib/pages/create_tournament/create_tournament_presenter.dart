import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_viewmodel.dart';
import 'package:tournament_management/utils.dart';

class CreateTournamentPresenter {
  final CreateTournamentViewModel viewModel;

  CreateTournamentPresenter(this.viewModel);

  Future<void> addGuest(BuildContext context) async {
    String? newGuest = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String guest = '';
        return AlertDialog(
          title: Text('add_guest'.tr()),
          content: TextField(
            onChanged: (value) => guest = value,
            decoration: InputDecoration(hintText: 'participant_name'.tr()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, guest),
              child: Text('add'.tr()),
            ),
          ],
        );
      },
    );

    if (newGuest != null && newGuest.isNotEmpty) {
      viewModel.addGuest(newGuest);
    }
  }

  void removeGuest(String guest) {
    viewModel.removeGuest(guest);
  }

  Future<void> pickTournamentDate(BuildContext context) async {
    DateTimeRange? rangeTournament = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(DateTime.now().year + 1),);


    if (rangeTournament != null) {
        DateTime startDate =  rangeTournament.start;
        DateTime endDate = rangeTournament.end;
        DateFormat  df = DateFormat("dd/MM/yyyy");

        String formattedDateStart =  df.format(startDate);
        String formattedDateEnd =  df.format(endDate);
        
         viewModel.setTournamentDate(formattedDateStart);
         viewModel.setTournamentEndDate(formattedDateEnd);
    }
  }
  

Future<void> submitTournament(BuildContext context) async {
  final tournamentName = viewModel.tournamentNameController.text.trim();
  final location = viewModel.locationController.text.trim();
  final createdBy = (FirebaseAuth.instance.currentUser?.email) ?? 'anonymous';

  if (tournamentName.isEmpty || location.isEmpty || viewModel.tournamentDate.isEmpty) {
    showErrorDialog(context, "missing_field".tr());
    return;
  }
  if (viewModel.guestList.length < 8) {
    showErrorDialog(context, "not_enough_people".tr());
    return;
  }

  final key = await viewModel.createTournament(createdBy: createdBy);

  if (key != null && context.mounted) {
    viewModel.resetFields();
    showDialogTournament(context);
  } else if (context.mounted) {
    showErrorDialog(context, viewModel.error ?? "Erreur inconnue");
  }
}

}
