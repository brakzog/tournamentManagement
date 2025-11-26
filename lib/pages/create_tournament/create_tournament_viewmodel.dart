import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tournament_management/data/repositories/tournament_repository.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/models/tournament_date.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';

class CreateTournamentViewModel extends ChangeNotifier {
  final TournamentRepository _repo;

  CreateTournamentViewModel(this._repo);

  // ----- Tes champs existants (inchang�s) -----
  final TextEditingController tournamentNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController eventTypeController = TextEditingController();
  String tournamentDate = "";
  String endTournamentDate = "";
  final List<String> guestList = [];

  // ----- �tat pour l�UI -----
  bool _loading = false;
  String? _error;
  String? _newKey;

  bool get isLoading => _loading;
  String? get error => _error;
  String? get newKey => _newKey;

  // ----- Helpers invit�s (compat + d�doublonnage) -----
  void addGuest(String guest) {
    final parts = guest.split(";")
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
    final toAdd = parts.where((g) => !guestList.contains(g)).toList();
    if (toAdd.isNotEmpty) {
      guestList.addAll(toAdd);
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
    _error = null;
    _newKey = null;
    notifyListeners();
  }

  // ----- Construction du mod�le � partir des champs -----
  Tournament _buildTournament({required String createdBy}) {
    final emptyMatch = MatchTournament(
      player1: '',
      player2: '',
      score: '',
      date: '',
      location: '',
    );

    return Tournament(
      name: tournamentNameController.text.trim(),
      sportEvent: eventTypeController.text.trim(),
      tournamentDate: TournamentDate(
        start: tournamentDate,
        end: endTournamentDate.isNotEmpty ? endTournamentDate : null,
      ),
      location: locationController.text.trim(),
      createdBy: createdBy,
      participants: guestList.toSet().toList(),
      pouleList: const [],
      finalMatchList: EndTournament(
        finalMatch: emptyMatch,
        smallFinalMatch: emptyMatch,
        semiFinalist: <MatchTournament>[],
        quarterFinalList: <MatchTournament>[],
      ),
    );
    // ?? Ton mod�le Tournament ne transporte pas l'id Firebase : on utilise la cl� retourn�e par le repo.
  }

  // ----- Action principale : cr�ation dans Firebase -----
  Future<String?> createTournament({required String createdBy}) async {
    // mini validation
    final name = tournamentNameController.text.trim();
    if (name.isEmpty) {
      _error = "Le nom du tournoi est obligatoire.";
      notifyListeners();
      return null;
    }
    if (tournamentDate.isEmpty) {
      _error = "La date de d�but est obligatoire.";
      notifyListeners();
      return null;
    }

    _loading = true;
    _error = null;
    _newKey = null;
    notifyListeners();

    try {
      final t = _buildTournament(createdBy: createdBy);
      final key = await _repo.createTournament(t);
      _newKey = key;
      return key;
    } catch (e, st) {
      _error = e.toString();
      if (kDebugMode) {
        print('CreateTournament error: $e');
        print(st);
      }
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    tournamentNameController.dispose();
    locationController.dispose();
    eventTypeController.dispose();
    super.dispose();
  }
}
