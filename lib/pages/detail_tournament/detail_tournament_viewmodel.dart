import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/utils.dart';

class DetailTournamentState {
  final int tabIndex;
  final bool isLoading;
  final bool isOwner;
  final String? errorMessage;


  final Tournament? tournament;
  final String? currentUserId;
  final bool isDeleting;
  final bool deleteSuccess;

  const DetailTournamentState({
    this.tabIndex = 0,
    this.isLoading = false,
    this.isOwner = false,
    this.errorMessage,
    this.tournament,
    this.currentUserId,
    this.isDeleting = false,
    this.deleteSuccess = false,
  });

  DetailTournamentState copyWith({
    int? tabIndex,
    bool? isLoading,
    bool? isOwner,
    String? errorMessage,
    Tournament? tournament,
    String? currentUserId,
    bool? isDeleting,
    bool? deleteSuccess,
  }) {
    return DetailTournamentState(
      tabIndex: tabIndex ?? this.tabIndex,
      isLoading: isLoading ?? this.isLoading,
      isOwner: isOwner ?? this.isOwner,
      errorMessage: errorMessage,
      tournament: tournament ?? this.tournament,
      currentUserId: currentUserId ?? this.currentUserId,
      isDeleting: isDeleting ?? this.isDeleting,
      deleteSuccess: deleteSuccess ?? this.deleteSuccess,
    );
  }


  bool get canDeleteTournament {
    final t = tournament;
    final uid = currentUserId;
    if (t == null || uid == null) return false;

    // Adapte ces noms à ton vrai modèle
    return t.createdBy == uid && t.finalMatchList.finalMatch != null;
  }
}




// --- INTENTS --- //

abstract class DetailTournamentIntent {
  const DetailTournamentIntent();
}

class ChangeTabIntent extends DetailTournamentIntent {
  final int index;
  const ChangeTabIntent(this.index);
}

class GeneratePoolsIntent extends DetailTournamentIntent {
  const GeneratePoolsIntent();
}

class DetailTournamentIntentDeleteRequested extends DetailTournamentIntent {
  const DetailTournamentIntentDeleteRequested();
}

class DetailTournamentIntentDeleteConfirmed extends DetailTournamentIntent {
  const DetailTournamentIntentDeleteConfirmed();
}



class DetailTournamentViewModel extends ChangeNotifier {
  final Tournament tournament;
  final bool inProgress;

  DetailTournamentState _state = const DetailTournamentState();
  DetailTournamentState get state => _state;

  DetailTournamentViewModel({
    required this.tournament,
    required this.inProgress,
  });


  Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _state = _state.copyWith(currentUserId: uid, isLoading: true);
    notifyListeners();
    _state = _state.copyWith(tournament: tournament, isLoading: false);
    notifyListeners();
  }


  void _setState(DetailTournamentState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(DetailTournamentIntent intent) async {
    if (intent is ChangeTabIntent) {
      _setState(_state.copyWith(tabIndex: intent.index));
    } else if (intent is GeneratePoolsIntent) {
      await _handleGeneratePools();
    } else if (intent is DetailTournamentIntentDeleteRequested) {
      _onDeleteTournament();
    } else if (intent is DetailTournamentIntentDeleteConfirmed) {
      _handleDeleteConfirmed();
    }
    // plus tard : autres intents
  }

  Future<void> _onDeleteTournament() async {
    final t = _state.tournament;
    if (t == null) return;

    _state = _state.copyWith(isDeleting: true);
    notifyListeners();

    try {
      await deleteTournament(t.name);

      _state = _state.copyWith(
        isDeleting: false,
        deleteSuccess: true,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(isDeleting: false);
      notifyListeners();
    }
  }


  Future<void> deleteTournament(String tournamentName) async {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");
    DatabaseReference tournament =
    tournamentRef.child(tournamentName);
    tournament.remove();
  }

  Future<void> _handleDeleteConfirmed() async {
    if (_state.isLoading) return;

    _setState(_state.copyWith(isLoading: true, errorMessage: null));

    try {
      final tournamentId = _state.tournamentId; // adapte selon ton state
      await FirebaseFirestore.instance
          .collection('tournaments') // adapte le nom
          .doc(tournamentId)
          .delete();

      _setState(_state.copyWith(
        isLoading: false,
        deleteSuccess: true,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: "Erreur suppression : $e",
      ));
    }
  }




  Future<void> _handleGeneratePools() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Génère les poules à partir des participants du tournoi
      await generatePoolsAndUpdateTournament();

      _setState(_state.copyWith(isLoading: false));
    } catch (e) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: "Erreur lors de la génération des poules : $e",
        ),
      );
    }
  }

  Future<void> generatePoolsAndUpdateTournament() async {
    // Génère les poules à partir des participants du tournoi
    final List<Poule> poules = generatePools(tournament.participants);

    // Met à jour le modèle en mémoire
    tournament.pouleList
      ..clear()
      ..addAll(poules);
  }

  List<Poule> generatePools(List<String> userList) {
    // Mélanger les utilisateurs
    List<String> shuffledUsers = List.from(userList)..shuffle();

    // Paramètres de configuration des groupes
    int numberOfGroups = 4;
    int usersPerGroup = shuffledUsers.length ~/ numberOfGroups;
    int remainingUsers = shuffledUsers.length % numberOfGroups;

    // Créer les groupes d'utilisateurs
    List<List<String>> userGroups = List.generate(numberOfGroups, (index) {
      // Calcul de l'index de départ et de fin
      int start = index * usersPerGroup + min(index, remainingUsers);
      int end = start + usersPerGroup + (index < remainingUsers ? 1 : 0);

      return shuffledUsers.sublist(start, end);
    });

    // Créer les poules à partir des groupes
    List<Poule> poules = List.generate(numberOfGroups, (index) {
      return Poule(
        name: String.fromCharCode('A'.codeUnitAt(0) + index),
        playerList: userGroups[index],
        matchList: _generateMatches(userGroups[index]),
      );
    });

    // Sauvegarder les poules dans Firebase
    _savePoolsToFirebase(poules);

    return poules;
  }

  List<MatchTournament> _generateMatches(List<String> userList) {
    List<MatchTournament> matches = [];
    for (int i = 0; i < userList.length - 1; i++) {
      for (int j = i + 1; j < userList.length; j++) {
        MatchTournament match = MatchTournament(
          player1: userList[i],
          player2: userList[j],
          score: '',
          date: '${calculateDate("poule")}',
          location: tournament.location,
        );
        matches.add(match);
      }
    }
    return matches;
  }

  String calculateDate(String phase) {
    DateTime startDate =
    DateFormat("dd/MM/yyyy").parse(tournament.tournamentDate.start!);
    DateTime endDate =
    DateFormat("dd/MM/yyyy").parse(tournament.tournamentDate.end!);

    int totalDays = endDate.difference(startDate).inDays;
    if (totalDays < 3) {
      throw Exception("Le tournoi doit durer au moins 3 jours.");
    }

    // Répartition des jours
    int phaseGroupDays = (totalDays * 0.6).floor();
    int quarterFinalsDays = (totalDays * 0.2).floor();
    int semiFinalsDays = (totalDays * 0.15).floor();
    int finalsDays =
        totalDays - (phaseGroupDays + quarterFinalsDays + semiFinalsDays);

    DateTime startPoule = startDate;
    DateTime startQuarter = startPoule.add(Duration(days: phaseGroupDays));
    DateTime startSemi =
    startQuarter.add(Duration(days: quarterFinalsDays));
    DateTime startFinal = startSemi.add(Duration(days: semiFinalsDays));

    Map<String, String> phases = {
      "poule": _formatDates(startPoule, phaseGroupDays),
      "1/4": _formatDates(startQuarter, quarterFinalsDays),
      "1/2": _formatDates(startSemi, semiFinalsDays),
      "finale": _formatDates(startFinal, finalsDays),
    };

    return phases[phase] ?? "Phase inconnue";
  }

  String _formatDates(DateTime startDate, int days) {
    DateTime endDate = startDate.add(Duration(days: days - 1));
    return "${DateFormat('dd-MM-yyyy').format(startDate)} → ${DateFormat('dd-MM-yyyy').format(endDate)}";
  }

  void _savePoolsToFirebase(List<Poule> poules) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");
    DatabaseReference poulesRef =
    tournamentRef.child(tournament.name).child('pouleList');

    // Convertir chaque poule en données et les sauvegarder
    for (var poule in poules) {
      Map<String, dynamic> pouleData = poule.toJson();
      pouleData.remove("name"); // Retirer le nom avant l'enregistrement
      poulesRef.child(poule.name).set(pouleData);
    }
  }

  Future<void> updateMatchGraph(
      DatabaseReference endTournamentRef, MatchTournament newMatch) async {
    final snapshot = await endTournamentRef.once();

    if (snapshot.snapshot.value != null) {
      Map<dynamic, dynamic> matches =
      snapshot.snapshot.value as Map<dynamic, dynamic>;
      matches.forEach((key, matchData) async {
        // Vérifier si le match correspond à celui que l'on souhaite mettre à jour
        if (matchData['player1'] == newMatch.player1 &&
            matchData['player2'] == newMatch.player2) {
          // Mettre à jour le score dans Firebase pour ce match
          await endTournamentRef.child(key).update(newMatch.toJson());
        }
      });
    }
  }

  Future<void> updateSemiFinal(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("semiFinal")
          .child(newIndex.toString())
          .update(
          tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateQuarterFinal(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.quarterFinalList.length > 1) {
      await endTournamentRef
          .child("quarterFinal")
          .child(newIndex.toString())
          .update(tournament.finalMatchList.quarterFinalList[index].toJson());
    }
  }

  Future<void> updateFinalMatch(
      DatabaseReference endTournamentRef, MatchTournament newMatch) async {
    await endTournamentRef.child("finalMatch").update(newMatch.toJson());
  }

  Future<void> updateSmallFinalMatch(
      DatabaseReference endTournamentRef, MatchTournament newMatch) async {
    await endTournamentRef.child("smallFinalMatch").update(newMatch.toJson());
  }

  Future<void> updateSemiFinalGraph(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("semiFinal")
          .child(newIndex.toString())
          .update(
          tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateQuarterFinalGraph(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.quarterFinalList.length > 1) {
      await endTournamentRef
          .child("quarterFinal")
          .child(newIndex.toString())
          .update(tournament.finalMatchList.quarterFinalList[index].toJson());
    }
  }

  Future<void> updateSemiFinalPlayers(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("semiFinal")
          .child(newIndex.toString())
          .child("player1")
          .update(tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateSmallFinalPlayers(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("smallFinal")
          .child(newIndex.toString())
          .child("player2")
          .update(tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateSemiFinalPlayersGraph(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("semiFinal")
          .child(newIndex.toString())
          .child("player1")
          .update(tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateSmallFinalPlayersGraph(
      DatabaseReference endTournamentRef, int index, int newIndex) async {
    if (tournament.finalMatchList.semiFinalist.length > 1) {
      await endTournamentRef
          .child("smallFinal")
          .child(newIndex.toString())
          .child("player2")
          .update(tournament.finalMatchList.semiFinalist[index].toJson());
    }
  }

  Future<void> updateMatch(
      DatabaseReference selectedPouleRef, MatchTournament newMatch) async {
    final snapshot = await selectedPouleRef.once();

    if (snapshot.snapshot.value != null) {
      Map<dynamic, dynamic> matches =
      snapshot.snapshot.value as Map<dynamic, dynamic>;

      matches.forEach((key, matchList) async {
        if (matchList is List<Object?>) {
          for (int i = 0; i < matchList.length; i++) {
            var element = matchList[i];

            if (element is Map<Object?, Object?>) {
              // Vérifier si les joueurs sont les mêmes, quel que soit l'ordre
              if ((element['player1'] == newMatch.player1 &&
                  element['player2'] == newMatch.player2) ||
                  (element['player1'] == newMatch.player2 &&
                      element['player2'] == newMatch.player1)) {
                try {
                  await selectedPouleRef
                      .child("matchs")
                      .child("$i")
                      .update(newMatch.toJson());
                } catch (e) {
                  print(
                      "Erreur lors de la mise à jour du match $i : $e");
                }
                break;
              }
            }
          }
        }
      });
    }
  }
}
