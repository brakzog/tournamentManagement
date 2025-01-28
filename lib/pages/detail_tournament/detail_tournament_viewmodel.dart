import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';

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
        );
        matches.add(match);
      }
    }
    return matches;
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
