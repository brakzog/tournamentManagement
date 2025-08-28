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

class TournamentViewmodel with ChangeNotifier {
  List<Tournament> inProgressTournament = [];
  List<Tournament> pastTournaments = [];
  List<Tournament> cancelNotPlayedTournaments = [];
  List<Tournament> tournaments = [];


  void navigateToDetailPage(BuildContext context, Tournament tournament, bool inProgress) {
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
        tournamentDate: tournamentDate,
        participants: participantsList.cast<String>(),
        pouleList: pouleList.cast<Poule>(),
        finalMatchList: finalMatchList,
        location: "${mapValue['location']}",
      );
      // Vérifiez si le tournoi appartient à l'utilisateur actuel (par exemple, par ID d'utilisateur).
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
        tournament.finalMatchList.finalMatch.score != ""
        ) {
      isChecked = addPastTournament(tournament, isChecked, past);
    }
    //Récupération de l'ensemble des tournois annulés ou pas joués
    if (!isChecked && tournament.tournamentDate.start == null) {
      cancel.add(tournament);
    }
    if (!isChecked) {
      //shold not happened from this point
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

  List<MatchTournament> getListMatch(List<Object?> objectList) {
    List<MatchTournament> returnList = [];
    for (var value in objectList) {
      Map<Object?, Object?> subMap = value as Map<Object?, Object?>;
      MatchTournament currentMatch = MatchTournament(
        player1: "${subMap['player1']}",
        player2: "${subMap['player2']}",
        score: "${subMap['score']}",
        date: "${subMap['date']}",
        location: "${subMap['location']}",
      );
      returnList.add(currentMatch);
    }
    return returnList;
  }

  List<String> getPlayerList(List<Object?> objectList) {
    return objectList.cast<String>();
  }

  EndTournament getListFinalMatch(Map<Object?, Object?> mapValue) {
    //Map<Object?, Object?> finalMap = mapValue['final'] as Map<Object?, Object?>;
    List<MatchTournament> quarterList = getMatchListMap('quartFinal', mapValue);
    List<MatchTournament> semiList = getMatchListMap('semiFinal', mapValue);
    MatchTournament smallFinall = getFinalMatch('smallFinal', mapValue);
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

    List<Object?> objectMap = mapValue[key] as List<Object?>;
    // List<Object?> objectList = objectMap.values as List<Object?>;
    List<MatchTournament> matchList = [];
    objectMap.forEach((element) {
        Map<Object?, Object?> valueMap = element as Map<Object?, Object?>;
        MatchTournament? currentMatch = MatchTournament(
          player1: "${valueMap['player1']}",
          player2: "${valueMap['player2']}",
          score: "${valueMap['score']}",
          date: "${valueMap['date']}",
          location: "${valueMap['location']}",
        );
        matchList.add(currentMatch);
      }
    );
    return matchList;
  }

  

  List<MatchTournament> getMatchList(
      String key, Map<Object?, Object?> mapValue) {
    if (mapValue[key] == null) {
      return [];
    }

    List<Object?> objectList = mapValue[key] as List<Object?>;
    // List<Object?> objectList = objectMap.values as List<Object?>;
    List<MatchTournament> matchList = [];
    objectList.forEach((currentElem) {

        Map<Object?, Object?> valueMap = currentElem as Map<Object?, Object?>;
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
      return MatchTournament(player1: "", player2: "", score: "", date: "", location: "");
    }
    Map<Object?, Object?> objectMap = mapValue[key] as Map<Object?, Object?>;
    return MatchTournament(
      player1: "${objectMap['player1']}",
      player2: "${objectMap['player2']}",
      score: "${objectMap['score']}",
      date: "${objectMap['date']}",
      location: "${objectMap['location']}",
    );
  }
}
