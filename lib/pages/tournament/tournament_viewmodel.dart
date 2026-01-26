import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/models/tournament_date.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament.dart';

/// --- MVI STATE --- ///
class TournamentState {
  final bool isLoading;
  final String? errorMessage;
  final List<Tournament> inProgress;
  final List<Tournament> past;
  final List<Tournament> cancel;

  const TournamentState({
    this.isLoading = false,
    this.errorMessage,
    this.inProgress = const [],
    this.past = const [],
    this.cancel = const [],
  });

  TournamentState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Tournament>? inProgress,
    List<Tournament>? past,
    List<Tournament>? cancel,
  }) {
    return TournamentState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      inProgress: inProgress ?? this.inProgress,
      past: past ?? this.past,
      cancel: cancel ?? this.cancel,
    );
  }
}

/// --- MVI INTENTS --- ///
abstract class TournamentIntent {
  const TournamentIntent();
}

class LoadTournamentsIntent extends TournamentIntent {
  const LoadTournamentsIntent();
}

class RefreshTournamentsIntent extends TournamentIntent {
  const RefreshTournamentsIntent();
}

/// --- VIEWMODEL --- ///
class TournamentViewmodel with ChangeNotifier {
  TournamentState _state = const TournamentState();
  TournamentState get state => _state;

  // On garde les listes d'origine (utile si d'autres écrans les utilisent plus tard)
  List<Tournament> inProgressTournament = [];
  List<Tournament> pastTournaments = [];
  List<Tournament> cancelNotPlayedTournaments = [];
  List<Tournament> tournaments = [];

  void _setState(TournamentState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(TournamentIntent intent) async {
    if (intent is LoadTournamentsIntent || intent is RefreshTournamentsIntent) {
      await _loadTournaments();
    }
  }

  Future<void> _loadTournaments() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        errorMessage: null,
      ),
    );

    // Réinitialise les listes locales
    inProgressTournament = [];
    pastTournaments = [];
    cancelNotPlayedTournaments = [];
    tournaments = [];

    try {
      await fetchTournamentsFromFirebase();

      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: null,
          inProgress: List.unmodifiable(inProgressTournament),
          past: List.unmodifiable(pastTournaments),
          cancel: List.unmodifiable(cancelNotPlayedTournaments),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Erreur lors du chargement des tournois : $e');
        print(st);
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Erreur lors du chargement des tournois : $e',
          inProgress: const [],
          past: const [],
          cancel: const [],
        ),
      );
    }
  }

  void navigateToDetailPage(
      BuildContext context, Tournament tournament, bool inProgress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailTournament(
          tournament: tournament,
          inProgress: inProgress,
        ),
      ),
    );
  }


  Future<Map<String, List<Tournament>>> fetchTournamentsFromFirebase() async {
    Map<String, List<Tournament>> mapReturn = HashMap();
    List<Tournament> inProgress = [];
    List<Tournament> past = [];
    List<Tournament> cancel = [];

    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
      return buildMapTournament(
          snapshot, inProgress /*, future*/, past, cancel, mapReturn);
    } else {
      if (kDebugMode) {
        print('No data available.');
      }
      return {"": List.empty()};
    }
  }

  Map<String, List<Tournament>> buildMapTournament(
      DataSnapshot snapshot,
      List<Tournament> inProgress,
      //  List<Tournament> future,
      List<Tournament> past,
      List<Tournament> cancel,
      Map<String, List<Tournament>> mapReturn) {
    Object? objectValue = snapshot.value as Map<Object?, Object?>;
    Map<Object?, Object?> map = objectValue as Map<Object?, Object?>;
    map.forEach((key, value) {
      Map<Object?, Object?> mapValue = value as Map<Object?, Object?>;

      final List<Object?> participantsList =
      mapValue["participants"] as List<Object?>;

      final List<Poule> pouleList = getPouleList(mapValue);
      final EndTournament finalMatchList = getListFinalMatch(mapValue);

      TournamentDate tournamentDate = getTournamentDate(mapValue);

      Tournament tournament = Tournament(
        createdBy: "${mapValue["createdBy"]}",
        name: "$key",
        sportEvent: "${mapValue["sportEvent"]}",
        participants: List<String>.from(participantsList),
        tournamentDate: tournamentDate,
        pouleList: pouleList,
        finalMatchList: finalMatchList,
        location: "${mapValue['location']}",
      );

      if (tournament.createdBy == FirebaseAuth.instance.currentUser?.email) {
        retrieveCurrentUserData(tournament, inProgress, past, cancel);
      } else {
        if (kDebugMode) {
          print(
              "not from connected user : ${FirebaseAuth.instance.currentUser?.email} != ${tournament.createdBy}");
        }
      }
    });
    this.inProgressTournament = inProgress;
    this.pastTournaments = past;
    this.cancelNotPlayedTournaments = cancel;
    mapReturn["past"] = past;
    mapReturn["present"] = inProgress;
    mapReturn["cancel"] = cancel;
    return mapReturn;
  }

  void retrieveCurrentUserData(
      Tournament tournament,
      List<Tournament> inProgress,
      List<Tournament> past,
      List<Tournament> cancel) {
    bool isChecked = false;
    //Recuperation de l'ensemble des tournois présents ou passés ou n'ayant pas pu avoir lieu
    tournaments.add(tournament);
    //Récupération de l'ensemble des tournois en cours
    if (tournament.tournamentDate.start != null &&
        tournament.pouleList.isEmpty ||
        tournament.finalMatchList.finalMatch.score.isEmpty) {
      isChecked = addInProgressTournament(tournament, isChecked, inProgress);
    }

    //Récupération de l'ensemble des tournois déjà joués
    if (!isChecked &&
        tournament.finalMatchList.finalMatch.player1 != "" &&
        tournament.finalMatchList.finalMatch.player2 != "" &&
        tournament.finalMatchList.finalMatch.score != "") {
      isChecked = addPastTournament(tournament, isChecked, past);
    }
    //Récupération de l'ensemble des tournois annulés ou pas joués
    if (!isChecked && tournament.tournamentDate.start == null) {
      cancel.add(tournament);
    }
    if (!isChecked) {
      //should not happen from this point
      if (kDebugMode) print("tournament not taken : $tournament");
    }
  }

  bool addPastTournament(
      Tournament tournament, bool isChecked, List<Tournament> past) {
    isChecked = true;
    past.add(tournament);
    return isChecked;
  }

  bool addInProgressTournament(
      Tournament tournament, bool isChecked, List<Tournament> inProgress) {
    if (tournament.finalMatchList.finalMatch.score.isEmpty) {
      inProgress.add(tournament);
      isChecked = true;
    }
    return isChecked;
  }

  TournamentDate getTournamentDate(Map<Object?, Object?> mapValue) {
    final dateMap = mapValue["tournamentDate"] as Map<Object?, Object?>;

    TournamentDate tournamentDate = TournamentDate(
      start: "${dateMap["beginingDate"]}",
      end: "${dateMap["endDate"]}",
    );

    return tournamentDate;
  }

  List<Poule> getPouleList(Map<Object?, Object?> mapValue) {
    if (mapValue['pouleList'] == null) {
      return [];
    }
    List<Poule> pouleList = [];
    final Map<Object?, Object?> pouleMap =
    mapValue['pouleList'] as Map<Object?, Object?>;
    pouleMap.forEach((key, value) {
      final String currentName = key as String;
      Map<Object?, Object?> valueMap = value as Map<Object?, Object?>;
      pouleList.add(Poule(
          name: currentName,
          matchList: getListMatch(valueMap['matchs'] as List<Object?>),
          playerList: getPlayerList(valueMap['players'] as List<Object?>)));
    });
    return pouleList;
  }

  List<MatchTournament> getListMatch(List<Object?> valueMap) {
    List<MatchTournament> list = [];

    valueMap.forEach((currentElem) {
      Map<Object?, Object?> map = currentElem as Map<Object?, Object?>;
      var element = MatchTournament(
          player1: "${map['player1']}",
          player2: "${map['player2']}",
          score: "${map['score']}",
          date: "${map['date']}",
          location: "${map['location']}");
      list.add(element);
    });

    return list;
  }

  List<String> getPlayerList(List<Object?> valueMap) {
    List<String> list = [];
    valueMap.forEach((currentElem) {
      list.add("$currentElem");
    });
    return list;
  }

  EndTournament getListFinalMatch(Map<Object?, Object?> mapValue) {
    //now need to retrieve quarterfinalist
    List<MatchTournament> semiList =
    getMatchListMap('semiFinal', mapValue);
    List<MatchTournament> quarterList =
    getMatchListMap('quartFinal', mapValue);
    //final and small final
    MatchTournament smallFinall =
    getFinalMatch('smallFinalMatch', mapValue);

    MatchTournament finale = getFinalMatch('finalMatch', mapValue);
    return EndTournament(
        finalMatch: finale,
        smallFinalMatch: smallFinall,
        semiFinalist: semiList,
        quarterFinalList: quarterList);
  }

  List<MatchTournament> getMatchListMap(
      String key, Map<Object?, Object?> mapValue) {
    if (mapValue[key] == null) {
      return [];
    }

    List<Object?> objectList = mapValue[key] as List<Object?>;
    // List<Object?> objectList = objectMap.values as List<Object?>;
    List<MatchTournament> matchList = [];
    objectList.forEach((currentElem) {
      Map<Object?, Object?> valueMap =
      currentElem as Map<Object?, Object?>;
      MatchTournament? currentMatch = MatchTournament(
        player1: "${valueMap['player1']}",
        player2: "${valueMap['player2']}",
        score: "${valueMap['score']}",
        date: "${valueMap['date']}",
        location: "${valueMap['location']}",
      );
      matchList.add(currentMatch);
    });
    return matchList;
  }

  MatchTournament getFinalMatch(String key, Map<Object?, Object?> mapValue) {
    if (mapValue[key] == null) {
      return MatchTournament(
          player1: "",
          player2: "",
          score: "",
          date: "",
          location: "");
    }
    Map<Object?, Object?> objectMap =
    mapValue[key] as Map<Object?, Object?>;
    return MatchTournament(
      player1: "${objectMap['player1']}",
      player2: "${objectMap['player2']}",
      score: "${objectMap['score']}",
      date: "${objectMap['date']}",
      location: "${objectMap['location']}",
    );
  }
}
