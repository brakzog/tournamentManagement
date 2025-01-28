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
          title: const Text('Ajouter un invité'),
          content: TextField(
            onChanged: (value) => guest = value,
            decoration: const InputDecoration(hintText: 'Nom de l\'invité'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, guest),
              child: const Text('Ajouter'),
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
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        String formattedDate = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
        viewModel.setTournamentDate(formattedDate);
      }
    }
  }

  /*void submitTournament(BuildContext context) {
    if (viewModel.tournamentNameController.text.isEmpty ||
        viewModel.locationController.text.isEmpty ||
        viewModel.eventTypeController.text.isEmpty ||
        viewModel.tournamentDate.isEmpty ||
        viewModel.guestList.isEmpty) {
      debugPrint("Veuillez remplir tous les champs requis.");
      return;
    }

    final newTournament = Tournament(createdBy: FirebaseAuth.instance.currentUser!.email!,
                                     name: viewModel.tournamentNameController.text,
                                     sportEvent: viewModel.eventTypeController.text,
                                     tournamentDate: viewModel.tournamentDate,
                                     participants: viewModel.guestList,
                                     pouleList: List.of(),
                                      finalMatchList: EndTournament(finalMatch: finalMatch, smallFinalMatch: smallFinalMatch, semiFinalist: semiFinalist, quarterFinalList: quarterFinalList))

    // Simule l'enregistrement
    debugPrint("Tournoi créé avec succès !");
    debugPrint("Nom : ${viewModel.tournamentNameController.text}");
    debugPrint("Lieu : ${viewModel.locationController.text}");
    debugPrint("Type : ${viewModel.eventTypeController.text}");
    debugPrint("Date : ${viewModel.tournamentDate}");
    debugPrint("Invités : ${viewModel.guestList.join(", ")}");
    Navigator.pop(context);
  }*/
  void submitTournament(BuildContext context) {
    String tournamentName = viewModel.tournamentNameController.text;
    String location = viewModel.locationController.text;

    // should always be not null as the user is already connected from here
    String createdBy = (FirebaseAuth.instance.currentUser!.email)!;

    if (tournamentName.isEmpty ||
        location.isEmpty ||
        viewModel.tournamentDate.isEmpty ||
        viewModel.guestList.isEmpty) {
      showErrorDialog(context,
          "Un des champs requis à la création du tournoi n'a pas été rempli. Veuillez le remplir avant de soumettre le tournoi");
      return;
    }

    // Get reference to tournament table from firebase
    DatabaseReference tournamentRef =
        FirebaseDatabase.instance.ref().child("tournois");

    // Get the key chosen from this table (should check its unicity)
    String key = '$tournamentName-${viewModel.locationController.text}';

    //At this point, we have not already participant list
    //(they have not confirmed yet their participation)
    Map<String, dynamic> tournamentData = {
      "createdBy": createdBy,
      "location": location,
      "participants": viewModel.guestList,
      "sportEvent": viewModel.eventTypeController.text,
      "tournamentDate": {
        "beginingDate": viewModel.tournamentDate,
      },
    };

    // Enregistrez le tournoi dans la base de données en utilisant la clé composite
    tournamentRef.child(key).set(tournamentData).then((value) {
      // Tournoi enregistré avec succès
      // Vous pouvez ajouter d'autres actions ici si nécessaire
      if (kDebugMode) {
        print("Tournoi enregistré avec succès");
      }
      showDialogTournament(context);
    }).catchError((error) {
      // Gestion des erreurs
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement du tournoi : $error");
      }
    });
  }

}
