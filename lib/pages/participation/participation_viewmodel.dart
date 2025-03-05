import 'dart:collection';
import 'dart:ffi';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tournament_management/models/participation_model.dart';

class ParticipationViewModel extends ChangeNotifier{



  Future<List<ParticipationModel>> fetchCalendarFromFirebase(bool played) async{
    
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
      return buildListParticipation(snapshot,played );
    } else {
      if (kDebugMode) {
        print('No data available.');
      }
      return List.empty();
    }
    
  }


  Future<List<ParticipationModel>> buildListParticipation(DataSnapshot snapshot, bool played) async {
    Object? objectValue = snapshot.value as Map<Object?, Object?>;
    Map<Object?, Object?> map = objectValue as Map<Object?, Object?>;
    List<ParticipationModel> returnList = [];

    await Future.forEach(map.entries, (MapEntry<Object?, Object?> entry) async {
       Map<Object?, Object?> mapValue = entry.value as Map<Object?, Object?>;

      final List<Object?> participantsList =
          mapValue["participants"] as List<Object?>;

          //FOR DEBUG
          String? currentUser = "a1";//FirebaseAuth.instance.currentUser?.email;
      if(participantsList.contains(currentUser)) {
        var unplayedMatches = getMatches(mapValue, "a1", played);
        returnList.addAll(unplayedMatches);
      }

    },);

    return returnList;
  }

  List<ParticipationModel> getMatches(Map<Object?, Object?> tournamentData, String userEmail, bool played) {
    List<ParticipationModel> unplayedMatches = [];

    // Vérification des phases finales
    List<String> eliminationRounds = ['finalMatch', 'semiFinal', 'quartFinal'];
    for (var round in eliminationRounds) {
      if (tournamentData[round] is Map<Object?, Object?>) {
        var roundData = tournamentData[round] as Map<Object?, Object?>;
        if(roundData["player1"] == userEmail || roundData["player2"] == userEmail && (played ? roundData["score"] != "" : roundData["score"] == "")) {
          Map<Object?, Object?> date = tournamentData["tournamentDate"] as Map<Object?, Object?>;
          unplayedMatches.add(ParticipationModel(date: date["beginDate"]!.toString(), location: tournamentData["location"]!.toString(), opposant: roundData["player1"] == userEmail? roundData["player2"].toString() : roundData["player1"].toString(), score: roundData['score'].toString()));
        }
      }
    }

    // Vérification des matchs de poule
    if (tournamentData['pouleList'] is Map<Object?, Object?>) {
      var pouleList = tournamentData['pouleList'] as Map<Object?, Object?>;

      for (var poule in pouleList.values) {
        if (poule is Map<Object?, Object?> && poule.containsKey('matchs') && poule['matchs'] is List) {
          var matchList = poule["matchs"] as List;
          for (var matchObject in matchList) {
            var matchMap = matchObject as Map<Object?, Object?>;
            if(matchMap["player1"] == userEmail || matchMap["player2"] == userEmail && (played? matchMap["score"] != "" : matchMap["score"] == "")) {
              Map<Object?, Object?> date = tournamentData["tournamentDate"] as Map<Object?, Object?>;
              unplayedMatches.add(ParticipationModel(date: date["beginingDate"]!.toString(), location: tournamentData["location"]!.toString(), opposant: matchMap["player1"] == userEmail? matchMap["player2"].toString() : matchMap["player1"].toString(), score: matchMap['score'].toString() ));
            }
          }
       }
      }
    }
    return unplayedMatches;
  }

}
