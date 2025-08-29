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
import 'package:tournament_management/data/repositories/tournament_repository.dart';

class TournamentViewmodel with ChangeNotifier {
  List<Tournament> inProgressTournament = [];
  List<Tournament> pastTournaments = [];
  List<Tournament> cancelNotPlayedTournaments = [];
  List<Tournament> tournaments = [];
  final TournamentRepository _repo = TournamentRepository();
  
  final Map<Tournament, String> _firebaseKeys = {};

  String? firebaseKeyOf(Tournament t) => _firebaseKeys[t];


  void navigateToDetailPage(BuildContext context, Tournament tournament, bool inProgress) {
     final fbKey = firebaseKeyOf(tournament); // peut être null si non mappé (ok)
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (_) => DetailTournament(
           tournament: tournament,
           inProgress: inProgress,
           tournamentKey: fbKey, // 🔹 on passe la clé
          ),
       ),
     );
  }


  Future<Map<String, List<Tournament>>> fetchTournamentsFromFirebase() async {
    Map<String, List<Tournament>> mapReturn = HashMap();
    List<Tournament> inProgress = [];
    List<Tournament> past = [];
    List<Tournament> cancel = [];

    // ⬇️ On lit via le Repository (plus de FirebaseDatabase direct ici)
    final raw = await _repo.fetchAllTournamentsRaw();
    if (raw.isEmpty) {
      if (kDebugMode) print('No data available.');
        return {"": List.empty()};
    }

    return buildMapTournamentFromMap(raw, inProgress, past, cancel, mapReturn);
  }
  
  
  
  Map<String, List<Tournament>> buildMapTournamentFromMap(
  Map<Object?, Object?> map,
  List<Tournament> inProgress,
  List<Tournament> past,
  List<Tournament> cancel,
  Map<String, List<Tournament>> mapReturn,
) {
  map.forEach((key, value) {
    if (value is! Map) return;
    final Map<Object?, Object?> mapValue = value;

    // participants: tolérant (List ou Map indexée)
    final participantsRaw = mapValue["participants"];
    final List<String> participantsList = () {
      if (participantsRaw is List) {
        return participantsRaw.map((e) => e.toString()).toList();
      } else if (participantsRaw is Map) {
        return participantsRaw.values.map((e) => e.toString()).toList();
      }
      return <String>[];
    }();

    final List<Poule> pouleList = getPouleList(mapValue);
    final EndTournament finalMatchList = getListFinalMatch(mapValue);
    final TournamentDate tournamentDate = getTournamentDate(mapValue);

    // ⚠️ Nouveau : si la DB contient un champ "name", on l’utilise.
    // Sinon, on garde ton ancien comportement: le nom = clé Firebase.
    final String tournamentName = (mapValue["name"]?.toString() ?? key.toString());

    final Tournament tournament = Tournament(
      createdBy: "${mapValue["createdBy"]}",
      name: tournamentName,
      sportEvent: "${mapValue["sportEvent"]}",
      tournamentDate: tournamentDate,
      participants: participantsList,
      pouleList: pouleList,
      finalMatchList: finalMatchList,
      location: "${mapValue['location']}",
    );
	
	_firebaseKeys[tournament] = key.toString();

    // Filtre : tournois de l’utilisateur courant
    if (tournament.createdBy == FirebaseAuth.instance.currentUser?.email) {
      retrieveCurrentUserData(tournament, inProgress, past, cancel);
    } else {
      if (kDebugMode) {
        print("not from connected user : ${FirebaseAuth.instance.currentUser?.email} != ${tournament.createdBy}");
      }
    }
  });
  
  // En cours : par date de début croissante
  inProgress.sort((a, b) =>
    _safeDate(a.tournamentDate.start).compareTo(_safeDate(b.tournamentDate.start)));

  // Passés : par date de fin (ou début) décroissante
  past.sort((a, b) =>
    _safeDate(b.tournamentDate.end ?? b.tournamentDate.start, fallbackMax: true)
      .compareTo(_safeDate(a.tournamentDate.end ?? a.tournamentDate.start, fallbackMax: true)));

  // Annulés / non joués : par date de début croissante (si connue)
  cancel.sort((a, b) =>
    _safeDate(a.tournamentDate.start).compareTo(_safeDate(b.tournamentDate.start)));

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
  List<Tournament> cancel,
) {
  // start est un String dans ton modèle → on teste le contenu
  final String start = tournament.tournamentDate.start;
  final bool hasStart = start.trim().isNotEmpty;

  // “tournoi terminé” = finale renseignée ET score présent
  final fm = tournament.finalMatchList.finalMatch;
  final bool finalsCompleted =
      fm.player1.trim().isNotEmpty &&
      fm.player2.trim().isNotEmpty &&
      fm.score.trim().isNotEmpty;

  if (finalsCompleted) {
    past.add(tournament);
    return;
  }
  if (hasStart) {
    // Tournoi démarré (ou planifié avec date) mais pas terminé
    inProgress.add(tournament);
    return;
  }
  // Pas de date → on le met dans “annulés / non joués”
  cancel.add(tournament);
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
  final raw = mapValue["tournamentDate"];

  if (raw is Map<Object?, Object?>) {
    final begin = (raw["beginingDate"] ?? raw["start"] ?? "").toString();
    final endRaw = (raw["endDate"] ?? raw["end"] ?? "").toString();
    final end = endRaw.trim().isEmpty ? null : endRaw;
    return TournamentDate(start: begin, end: end);
  }

  // Fallback si la structure n’est pas celle attendue
  return const TournamentDate(start: "", end: null);
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
  
  DateTime? _parseDateNullable(String s) {
    final raw = (s).trim();
    if (raw.isEmpty) return null;

    // ISO (yyyy-MM-dd[THH:mm...])
    try { return DateTime.parse(raw.split(' ').first); } catch (_) {}

    // dd/MM/yyyy
    try {
      final p = raw.split(RegExp(r'[/\-.]'));
      if (p.length >= 3) {
        final d = int.parse(p[0]), m = int.parse(p[1]), y = int.parse(p[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}

    return null;
  }

  DateTime _safeDate(String s, {bool fallbackMax = false}) {
    final dt = _parseDateNullable(s);
    if (dt != null) return dt;
    // Si on veut trier “passés” en récent d’abord, on peut inverser le fallback
    return fallbackMax ? DateTime(9999) : DateTime.fromMillisecondsSinceEpoch(0);
  }

}
