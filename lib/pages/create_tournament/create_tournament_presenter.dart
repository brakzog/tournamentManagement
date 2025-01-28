import 'package:flutter/material.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_viewmodel.dart';

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

  void submitTournament() {
    if (viewModel.tournamentNameController.text.isEmpty ||
        viewModel.locationController.text.isEmpty ||
        viewModel.eventTypeController.text.isEmpty ||
        viewModel.tournamentDate.isEmpty ||
        viewModel.guestList.isEmpty) {
      debugPrint("Veuillez remplir tous les champs requis.");
      return;
    }

    // Simule l'enregistrement
    debugPrint("Tournoi créé avec succès !");
    debugPrint("Nom : ${viewModel.tournamentNameController.text}");
    debugPrint("Lieu : ${viewModel.locationController.text}");
    debugPrint("Type : ${viewModel.eventTypeController.text}");
    debugPrint("Date : ${viewModel.tournamentDate}");
    debugPrint("Invités : ${viewModel.guestList.join(", ")}");
  }
}
