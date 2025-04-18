import 'package:flutter/material.dart';

class CreateTournamentViewModel extends ChangeNotifier {
  final TextEditingController tournamentNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController eventTypeController = TextEditingController();
  String tournamentDate = "";
  String endTournamentDate = "";
  final List<String> guestList = [];

  void addGuest(String guest) {
    List<String> newguestList = guest.split(";");
    List<String> newGuestToAdd = newguestList.where((guest) => !guestList.contains(guest)).toList();
    if (!guestList.contains(guest)) {
      guestList.addAll(newGuestToAdd);
      notifyListeners();
    }
  }

  void removeGuest(String guest) {
    guestList.remove(guest);
    notifyListeners();
  }

  void setTournamentDate(String date) {
    tournamentDate = date;
    notifyListeners();
  }

  void setTournamentEndDate(String date) {
    endTournamentDate = date;
    notifyListeners();
  }

  void resetFields() {
    tournamentNameController.text = "";
    locationController.text = "";
    eventTypeController.text = "";
    tournamentDate = "";
    endTournamentDate = "";
    guestList.clear();
  }
}
