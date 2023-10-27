import 'dart:async';

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
  List<Tournament> upcomingTournaments = [];
  List<Tournament> pastTournaments = [];
  List<Tournament> cancelNotPlayedTournaments = [];
  List<Tournament> inProgressTournament = [];

  @override
  void initState() {
    super.initState();
    fetchTournamentsFromFirebase();
  }

  Future<void> fetchTournamentsFromFirebase() async {
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
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
          bool isChecked = false;

          // setState(() {
          //Recuperation de l'ensemble des tournois présents ou passés ou n'ayant pas pu avoir lieu
          tournaments.add(tournament);
          //Récupération de l'ensemble des tournois en cours
          if (tournament.tournamentDate.beginingDate != null &&
              tournament.tournamentDate.finalDate != null) {
            DateTime beginTournament = DateFormat('dd/MM/yyyy').parse(
                tournament.tournamentDate.beginingDate!); //securisé au dessus
            DateTime finaleDate = DateFormat('dd/MM/yyyy').parse(
                tournament.tournamentDate.finalDate!); //securisé au dessus
            if (beginTournament.isBefore(DateTime.now()) &&
                finaleDate.isAfter(DateTime.now())) {
              isChecked = true;
              if (kDebugMode) print("tournoi en cours : $tournament");
              inProgressTournament.add(tournament);
            }
          }
          //Recuperation de l'ensemble des tournois à venir
          if (!isChecked && tournament.tournamentDate.beginingDate != null) {
            DateTime tournamentDate = DateFormat('dd/MM/yyyy').parse(
                tournament.tournamentDate.beginingDate!); //securisé au dessus
            if (tournamentDate.isAfter(DateTime.now())) {
              if (kDebugMode) print("tournoi à venir : $tournament");
              isChecked = true;
              upcomingTournaments.add(tournament);
            }
          }
          //Récupération de l'ensemble des tournois déjà joués
          if (!isChecked && tournament.tournamentDate.finalDate != null) {
            DateTime finalTournamentDate = DateFormat('dd/MM/yyyy').parse(
                tournament.tournamentDate.finalDate!); //securisé au dessus
            if (finalTournamentDate.isBefore(DateTime.now())) {
              if (kDebugMode) print("tournoi déjà joué : $tournament");

              isChecked = true;
              pastTournaments.add(tournament);
            }
          }

          //Récupération de l'ensemble des tournois annulés ou pas joués
          if (!isChecked && tournament.tournamentDate.beginingDate == null) {
            if (kDebugMode) print("tournoi n'ayant pas eu lieu : $tournament");

            cancelNotPlayedTournaments.add(tournament);
          }
          if (!isChecked) {
            //shold not happened from this point
            if (kDebugMode) print("tournament not taken : $tournament");
          }
          //    });
          setState(() {
            tournaments;
            inProgressTournament;
            pastTournaments;
            cancelNotPlayedTournaments;
            upcomingTournaments;
          });
        } else {
          if (kDebugMode) {
            print(
                "not from connected user : ${FirebaseAuth.instance.currentUser?.email} != ${tournament.createdBy}");
          }
        }
      });
    } else {
      if (kDebugMode) {
        print('No data available.');
      }
    }
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
      body: ListView.builder(
        itemCount: tournaments.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(tournaments[index].name),
            subtitle: Text(tournaments[index].createdBy),
            // Vous pouvez ajouter d'autres informations du tournoi ici.
          );
        },
      ),
    );
  }
}
