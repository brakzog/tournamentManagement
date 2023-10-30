import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tournament_management/tournament.dart';

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

      TournamentDate tournamentDate = getTournamentDate(mapValue);

      Tournament tournament = Tournament(
        createdBy: "${mapValue["createdBy"]}",
        name: "$key",
        sportEvent: "${mapValue["sportEvent"]}",
        tournamentDate: tournamentDate,
        participants: participantsList.cast<String>(),
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
    final suggestionDates = dateMap["suggestionDate"] as List<Object?>;
    final pouleDates = dateMap["pouleListDate"] as List<Object?>?;
    final quarterDates = dateMap["quarterListDate"] as List<Object?>?;
    final semiDates = dateMap["semiListDate"] as List<Object?>?;
    final finalDate = dateMap["finalDate"];

    TournamentDate tournamentDate = TournamentDate(
      beginingDate: "${dateMap["beginingDate"]}",
      suggestionDate: suggestionDates.cast<String>(),
      expirationDate: " ${dateMap["expirationDate"]}",
    );
    if (pouleDates != null) {
      tournamentDate.pouleListDate = pouleDates.cast<String>();
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
