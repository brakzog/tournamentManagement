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
  

  void submitTournament(BuildContext context) {
    String tournamentName = viewModel.tournamentNameController.text;
    String location = viewModel.locationController.text;

    // should always be not null as the user is already connected from here
    String createdBy = (FirebaseAuth.instance.currentUser!.email)!;

    if (tournamentName.isEmpty ||
        location.isEmpty ||
        viewModel.tournamentDate.isEmpty) {
      showErrorDialog(context,
          "missing_field".tr());
      return;
    }

    if(viewModel.guestList.length < 8) {
      showErrorDialog(context, "not_enough_people".tr());
      return;
    }

    // Get reference to tournament table from firebase
    DatabaseReference tournamentRef =
        FirebaseDatabase.instance.ref().child("tournois");

    // Get the key chosen from this table (should check its unicity)
    String key = '$tournamentName-${viewModel.eventTypeController.text}_${Random().nextInt(5000)}';

    //At this point, we have not already participant list
    //(they have not confirmed yet their participation)
    Map<String, dynamic> tournamentData = {
      "createdBy": createdBy,
      "location": location,
      "participants": viewModel.guestList,
      "sportEvent": viewModel.eventTypeController.text,
      "tournamentDate": {
        "beginingDate": viewModel.tournamentDate,
        "endDate": viewModel.endTournamentDate,
      },
    };

    // Enregistrez le tournoi dans la base de données en utilisant la clé composite
    tournamentRef.child(key).set(tournamentData).then((value) {
      // Tournoi enregistré avec succès
      // Vous pouvez ajouter d'autres actions ici si nécessaire
      if (kDebugMode) {
        print("Tournoi enregistré avec succès");
      }
      viewModel.resetFields();
      showDialogTournament(context);
    }).catchError((error) {
      // Gestion des erreurs
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement du tournoi : $error");
      }
    });
  }

}
