import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  TournamentsScreenState createState() => TournamentsScreenState();
}

class TournamentsScreenState extends State<TournamentScreen> {
  // ignore: deprecated_member_use
  final databaseReference = FirebaseDatabase.instance.reference();
  List<Tournament> tournaments = [];
  late List<Tournament> upcomingTournaments = [];
  late List<Tournament> pastTournaments = [];
  late List<Tournament> cancelNotPlayedTournaments = [];
  late List<Tournament> inProgressTournament = [];

  @override
  void initState() {
    super.initState();
    fetchTournamentsFromFirebase().then((map) {
      pastTournaments = map["past"] as List<Tournament>;
      inProgressTournament = map["present"] as List<Tournament>;
      upcomingTournaments = map["future"] as List<Tournament>;
      cancelNotPlayedTournaments = map["cancel"] as List<Tournament>;
    });
  }

  Future<Map<String, List<Tournament>>> fetchTournamentsFromFirebase() async {
    Map<String, List<Tournament>> mapReturn = HashMap();
    List<Tournament> inProgress = [];
    List<Tournament> past = [];
    List<Tournament> future = [];
    List<Tournament> cancel = [];

    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
      return buildMapTournament(
          snapshot, inProgress, future, past, cancel, mapReturn);
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
      List<Tournament> future,
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
      );
      // Vérifiez si le tournoi appartient à l'utilisateur actuel (par exemple, par ID d'utilisateur).
      if (tournament.createdBy == FirebaseAuth.instance.currentUser?.email) {
        retrieveCurrentUserData(tournament, inProgress, future, past, cancel);
      } else {
        if (kDebugMode) {
          print(
              "not from connected user : ${FirebaseAuth.instance.currentUser?.email} != ${tournament.createdBy}");
        }
      }
    });
    mapReturn["past"] = past;
    mapReturn["present"] = inProgress;
    mapReturn["future"] = future;
    mapReturn["cancel"] = cancel;
    return mapReturn;
  }

  void retrieveCurrentUserData(
      Tournament tournament,
      List<Tournament> inProgress,
      List<Tournament> future,
      List<Tournament> past,
      List<Tournament> cancel) {
    bool isChecked = false;
    //Recuperation de l'ensemble des tournois présents ou passés ou n'ayant pas pu avoir lieu
    tournaments.add(tournament);
    //Récupération de l'ensemble des tournois en cours
    if (tournament.tournamentDate.beginingDate != null &&
        tournament.tournamentDate.finalDate != null) {
      isChecked = addInProgressTournament(tournament, isChecked, inProgress);
    }
    //Recuperation de l'ensemble des tournois à venir
    if (!isChecked && tournament.tournamentDate.beginingDate != null) {
      isChecked = addFutureTournament(tournament, isChecked, future);
    }
    //Récupération de l'ensemble des tournois déjà joués
    if (!isChecked && tournament.tournamentDate.finalDate != null) {
      isChecked = addPastTournament(tournament, isChecked, past);
    }
    //Récupération de l'ensemble des tournois annulés ou pas joués
    if (!isChecked && tournament.tournamentDate.beginingDate == null) {
      cancel.add(tournament);
    }
    if (!isChecked) {
      //shold not happened from this point
      if (kDebugMode) print("tournament not taken : $tournament");
    }
  }

  bool addPastTournament(
      Tournament tournament, bool isChecked, List<Tournament> past) {
    DateTime finalTournamentDate = DateFormat('dd/MM/yyyy')
        .parse(tournament.tournamentDate.finalDate!); //securisé au dessus
    if (finalTournamentDate.isBefore(DateTime.now())) {
      if (kDebugMode) print("tournoi déjà joué : $tournament");

      isChecked = true;
      past.add(tournament);
    }
    return isChecked;
  }

  bool addFutureTournament(
      Tournament tournament, bool isChecked, List<Tournament> future) {
    DateTime tournamentDate = DateFormat('dd/MM/yyyy')
        .parse(tournament.tournamentDate.beginingDate!); //securisé au dessus
    if (tournamentDate.isAfter(DateTime.now())) {
      if (kDebugMode) print("tournoi à venir : $tournament");
      isChecked = true;
      future.add(tournament);
    }
    return isChecked;
  }

  bool addInProgressTournament(
      Tournament tournament, bool isChecked, List<Tournament> inProgress) {
    DateTime beginTournament = DateFormat('dd/MM/yyyy')
        .parse(tournament.tournamentDate.beginingDate!); //securisé au dessus
    DateTime finaleDate = DateFormat('dd/MM/yyyy')
        .parse(tournament.tournamentDate.finalDate!); //securisé au dessus
    if (beginTournament.isBefore(DateTime.now()) &&
        finaleDate.isAfter(DateTime.now())) {
      isChecked = true;
      if (kDebugMode) print("tournoi en cours : $tournament");
      //  inProgressTournament.add(tournament);
      inProgress.add(tournament);
    }
    return isChecked;
  }

  TournamentDate getTournamentDate(Map<Object?, Object?> mapValue) {
    final dateMap = mapValue["tournamentDate"] as Map<Object?, Object?>;

    final suggestionDates = dateMap["suggestionDate"] != null
        ? dateMap["suggestionDate"] as List<Object?>
        : null;
    final pouleDates = dateMap["pouleListDate"] as Map<Object?, Object?>?;
    final quarterDates = dateMap["quarterListDate"] as List<Object?>?;
    final semiDates = dateMap["semiListDate"] as List<Object?>?;
    final finalDate = dateMap["finalDate"];

    TournamentDate tournamentDate = TournamentDate(
      beginingDate: "${dateMap["beginingDate"]}",
      suggestionDate:
          suggestionDates != null ? suggestionDates.cast<String>() : [],
      expirationDate: " ${dateMap["expirationDate"]}",
    );
    if (pouleDates != null) {
      pouleDates.forEach((key, value) {
        tournamentDate.pouleListDate?.add("$value");
      });
    }
    if (quarterDates != null) {
      tournamentDate.quarterListDate = quarterDates.cast<String>();
    }
    if (semiDates != null) {
      tournamentDate.semiListDate = semiDates.cast<String>();
    }
    if (finalDate != null) {
      tournamentDate.finalDate = "$finalDate";
    }
    return tournamentDate;
  }

  List<Poule> getPouleList(Map<Object?, Object?> mapValue) {
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
    List<MatchTournament> quarterList = getMatchList('quartFinal', mapValue);
    List<MatchTournament> semiList = getMatchList('semiFinal', mapValue);
    MatchTournament smallFinall = getFinalMatch('smallFinal', mapValue);
    MatchTournament finale = getFinalMatch('final', mapValue);
    return EndTournament(
        finalMatch: finale,
        smallFinalMatch: smallFinall,
        semiFinalist: semiList,
        quarterFinalList: quarterList);
  }

  List<MatchTournament> getMatchList(
      String key, Map<Object?, Object?> mapValue) {
    Map<Object?, Object?> objectMap = mapValue[key] as Map<Object?, Object?>;
    // List<Object?> objectList = objectMap.values as List<Object?>;
    List<MatchTournament> matchList = [];
    objectMap.forEach((key, value) {
      List<Object?> valueList = value as List<Object?>;
      for (var element in valueList) {
        Map<Object?, Object?> valueMap = element as Map<Object?, Object?>;
        MatchTournament? currentMatch = MatchTournament(
          player1: "${valueMap['player1']}",
          player2: "${valueMap['player2']}",
          score: "${valueMap['score']}",
        );
        matchList.add(currentMatch);
      }
    });
    return matchList;
  }

  MatchTournament getFinalMatch(String key, Map<Object?, Object?> mapValue) {
    Map<Object?, Object?> objectMap = mapValue[key] as Map<Object?, Object?>;
    return MatchTournament(
      player1: "${objectMap['player1']}",
      player2: "${objectMap['player2']}",
      score: "${objectMap['score']}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Tournois"),
      ),
      body: FutureBuilder<Map<String, List<Tournament>>>(
        future: fetchTournamentsFromFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error fetching data'));
          } else if (snapshot.hasData) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) {
                return _buildList(index);
              },
            );
          } else {
            return const Center(child: Text('No data available'));
          }
        },
      ),
    );
  }

  Widget _buildList(int index) {
    List<List<Tournament>> tournamentCategories = [
      inProgressTournament,
      upcomingTournaments,
      pastTournaments,
      cancelNotPlayedTournaments,
    ];

    List<String> categoryTitles = [
      "Current Playing",
      "Next Tournaments",
      "Past Tournaments",
      "Cancelled Tournaments",
    ];

    if (tournamentCategories[index].isNotEmpty) {
      return ExpansionTile(
        title: Text(categoryTitles[index]),
        children: retrieveListWidget(tournamentCategories[index]),
      );
    } else {
      return ListTile(
        title: Text(categoryTitles[index]),
      );
    }
  }

  List<Widget> retrieveListWidget(List<Tournament> tournamentList) {
    List<Widget> listWidget = [];
    // ignore: avoid_function_literals_in_foreach_calls
    tournamentList.forEach((element) {
      listWidget.add(Column(
        children: [Text(element.name), Text(element.createdBy)],
      ));
    });

    return listWidget;
  }
}
