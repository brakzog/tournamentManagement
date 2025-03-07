import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/utils.dart';

class DetailTournamentViewModel extends ChangeNotifier{

  final Tournament? tournament;

  DetailTournamentViewModel({this.tournament});



  Future<void> generatePoolsAndUpdateTournament(Tournament tournament) async {
    // Logique métier ici, telle que la génération des poules
    List<Poule> poules = generatePools(tournament.participants);

    // Mise à jour du modèle ou de la base de données ici
    tournament.pouleList.addAll(poules);
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
          location: tournament!.location,
        );
        matches.add(match);
      }
    }
    return matches;
  }

  String calculateDate(String phase) {
    DateTime startDate = DateFormat("dd/MM/yyyy").parse(tournament!.tournamentDate.beginingDate!);
    DateTime endDate = DateFormat("dd/MM/yyyy").parse(tournament!.tournamentDate.endDate!);


    int totalDays = endDate.difference(startDate).inDays;
    if (totalDays < 3) {
      throw Exception("Le tournoi doit durer au moins 3 jours.");
    }

    // Répartition des jours
    int phaseGroupDays = (totalDays * 0.6).floor();
    int quarterFinalsDays = (totalDays * 0.2).floor();
    int semiFinalsDays = (totalDays * 0.15).floor();
    int finalsDays = totalDays - (phaseGroupDays + quarterFinalsDays + semiFinalsDays);

    DateTime startPoule = startDate;
    DateTime startQuarter = startPoule.add(Duration(days: phaseGroupDays));
    DateTime startSemi = startQuarter.add(Duration(days: quarterFinalsDays));
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
    DatabaseReference poulesRef = tournamentRef.child(tournament!.name).child('pouleList');

    // Convertir chaque poule en données et les sauvegarder
    for (var poule in poules) {
      Map<String, dynamic> pouleData = poule.toJson();
      pouleData.remove("name");  // Retirer le nom avant l'enregistrement
      poulesRef.child(poule.name).set(pouleData);
    }
  }

  Future<void> updateMatchGraph(DatabaseReference endTournamentRef, MatchTournament newMatch) async {
    final snapshot = await endTournamentRef.once();

    if (snapshot.snapshot.value != null) {
      Map<dynamic, dynamic> matches = snapshot.snapshot.value as Map<dynamic, dynamic>;
      matches["score"] = newMatch.score;
      try { 
        await endTournamentRef.update(newMatch.toJson());
        print("Match $newMatch mis à jour");
        updateNextStep(newMatch, endTournamentRef);
      } catch (e) {
                  print("Erreur lors de la mise à jour du match : $e");
      }
    }
  }

  Future<void> updateNextStep(MatchTournament match, DatabaseReference ref) async {
    final winner = getWinner(match);
    if(ref.parent?.key == "quartFinal") {
      prepareSemiFinal(ref, match, winner);
    } else if(ref.parent?.key == "semiFinal") {
      prepareFinal(ref, match, winner);
    } 
  }

  void prepareFinal(DatabaseReference ref, MatchTournament match, String winner) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois").child(tournament!.name);
    final index = tournament?.getIndex(tournament!.finalMatchList.semiFinalist, match);
    int newIndex = index! < 1 ? 0 : 1;


    if(newIndex == 0) {
      tournament?.finalMatchList.finalMatch.player1 = winner;
    } else {
      tournament?.finalMatchList.finalMatch.player2 = winner;
    }
    tournamentRef.child("finalMatch").update(tournament!.finalMatchList.finalMatch.toJson());
  }

  void prepareSemiFinal(DatabaseReference ref, MatchTournament match, String winner) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois").child(tournament!.name);
    final index = tournament?.getIndex(tournament!.finalMatchList.quarterFinalList, match);
    int newIndex = index! < 2 ? 0 : 1;
      
    if (tournament?.finalMatchList.semiFinalist[newIndex].player1.isEmpty == true) {
      tournament?.finalMatchList.semiFinalist[newIndex].player1 = winner;
      tournamentRef.child("semiFinal").child(newIndex.toString()).child("player1").update(tournament!.finalMatchList.semiFinalist[index].toJson());
    } else {
      tournament?.finalMatchList.semiFinalist[newIndex].player2 = winner;
      tournamentRef.child("semiFinal").child(newIndex.toString()).child("player2").update(tournament!.finalMatchList.semiFinalist[index].toJson());
    }
  }
  


  Future<void> updateMatch(DatabaseReference selectedPouleRef, MatchTournament newMatch) async {
    final snapshot = await selectedPouleRef.once();

    if (snapshot.snapshot.value != null) {
      Map<dynamic, dynamic> matches = snapshot.snapshot.value as Map<dynamic, dynamic>;

      matches.forEach((key, matchList) async {
        if (matchList is List<Object?>) {
          for (int i = 0; i < matchList.length; i++) {
            var element = matchList[i];

            if (element is Map<Object?, Object?>) {
              if ((element['player1'] == newMatch.player1 && element['player2'] == newMatch.player2) ||
                  (element['player2'] == newMatch.player1 && element['player1'] == newMatch.player2)) {
                try {
                  await selectedPouleRef.child("matchs").child("$i").update(newMatch.toJson());
                } catch (e) {
                  print("Erreur lors de la mise à jour du match $i : $e");
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
