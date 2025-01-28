import 'package:flutter/material.dart';

class CreateTournamentViewModel extends ChangeNotifier {
  final TextEditingController tournamentNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController eventTypeController = TextEditingController();
  String tournamentDate = "";
  final List<String> guestList = [];

  void addGuest(String guest) {
    if (!guestList.contains(guest)) {
      guestList.add(guest);
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
}
