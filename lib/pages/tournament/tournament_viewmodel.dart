import 'dart:async';
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

class StartListeningTournamentsIntent extends TournamentIntent {
  const StartListeningTournamentsIntent();
}

class StopListeningTournamentsIntent extends TournamentIntent {
  const StopListeningTournamentsIntent();
}

/// --- VIEWMODEL --- ///
class TournamentViewmodel with ChangeNotifier {
  TournamentState _state = const TournamentState();
  TournamentState get state => _state;

  StreamSubscription<DatabaseEvent>? _tournoisSub;

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
    if (intent is StartListeningTournamentsIntent) {
      _startListening();
      return;
    }
    if (intent is StopListeningTournamentsIntent) {
      await _stopListening();
      return;
    }
    if (intent is LoadTournamentsIntent || intent is RefreshTournamentsIntent) {
      await _loadTournaments();
    }
  }

  void _startListening() {
    if (_tournoisSub != null) return; // déjà abonné

    _setState(_state.copyWith(isLoading: true, errorMessage: null));

    final ref = FirebaseDatabase.instance.ref().child('tournois');
    _tournoisSub = ref.onValue.listen(
          (event) {
        final snapshot = event.snapshot;
        _applySnapshot(snapshot);
      },
      onError: (e) {
        if (kDebugMode) {
          print('Erreur abonnement tournois: $e');
        }
        _setState(
          _state.copyWith(
            isLoading: false,
            errorMessage: 'Erreur abonnement tournois: $e',
            inProgress: const [],
            past: const [],
            cancel: const [],
          ),
        );
      },
    );
  }

  Future<void> _stopListening() async {
    await _tournoisSub?.cancel();
    _tournoisSub = null;
  }

  void _applySnapshot(DataSnapshot snapshot) {
    // Reset pour éviter les doublons
    tournaments.clear();
    inProgressTournament = [];
    pastTournaments = [];
    cancelNotPlayedTournaments = [];

    if (!snapshot.exists) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: null,
          inProgress: const [],
          past: const [],
          cancel: const [],
        ),
      );
      return;
    }

    final mapReturn = HashMap<String, List<Tournament>>();
    buildMapTournament(
      snapshot,
      <Tournament>[],
      <Tournament>[],
      <Tournament>[],
      mapReturn,
    );

    _setState(
      _state.copyWith(
        isLoading: false,
        errorMessage: null,
        inProgress: List.unmodifiable(inProgressTournament),
        past: List.unmodifiable(pastTournaments),
        cancel: List.unmodifiable(cancelNotPlayedTournaments),
      ),
    );
  }

  Future<void> _loadTournaments() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
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
    } catch (e) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Erreur lors du chargement : $e',
          inProgress: const [],
          past: const [],
          cancel: const [],
        ),
      );
    }
  }

  Future<Map<String, List<Tournament>>> fetchTournamentsFromFirebase() async {
    Map<String, List<Tournament>> mapReturn = HashMap();
    List<Tournament> inProgress = [];
    List<Tournament> past = [];
    List<Tournament> cancel = [];

    // éviter doublons même en one-shot
    tournaments.clear();
    inProgressTournament = [];
    pastTournaments = [];
    cancelNotPlayedTournaments = [];

    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
      return buildMapTournament(snapshot, inProgress, past, cancel, mapReturn);
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
      List<Tournament> past,
      List<Tournament> cancel,
      Map<String, List<Tournament>> mapReturn,
      ) {
    Object? objectValue = snapshot.value as Map<Object?, Object?>;
    Map<Object?, Object?> map = objectValue as Map<Object?, Object?>;

    map.forEach((key, value) {
      final tournamentId = "$key";
      Map<Object?, Object?> mapValue = value as Map<Object?, Object?>;

      final participantsRaw = mapValue["participants"];
      final List<Object?> participantsList =
      (participantsRaw is List) ? participantsRaw : <Object?>[];

      final List<Poule> pouleList = getPouleList(mapValue);
      final EndTournament finalMatchList = getListFinalMatch(mapValue);

      TournamentDate tournamentDate = getTournamentDate(mapValue);

      final tournamentName = (mapValue["name"] ?? '').toString();

      Tournament tournament = Tournament(
        id: tournamentId,
        createdBy: "${mapValue["createdBy"]}",
        name: tournamentName,
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
            "not from connected user : ${FirebaseAuth.instance.currentUser?.email} != ${tournament.createdBy}",
          );
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
      List<Tournament> cancel,
      ) {
    bool isChecked = false;

    tournaments.add(tournament);

    if (tournament.tournamentDate.start != null &&
        tournament.pouleList.isEmpty ||
        tournament.finalMatchList.finalMatch.score.isEmpty) {
      isChecked = addInProgressTournament(tournament, isChecked, inProgress);
    }

    if (!isChecked &&
        tournament.finalMatchList.finalMatch.player1 != "" &&
        tournament.finalMatchList.finalMatch.player2 != "" &&
        tournament.finalMatchList.finalMatch.score != "") {
      isChecked = addPastTournament(tournament, isChecked, past);
    }

    if (!isChecked && tournament.tournamentDate.start == null) {
      cancel.add(tournament);
    }

    if (!isChecked) {
      if (kDebugMode) print("tournament not taken : $tournament");
    }
  }

  bool addPastTournament(
      Tournament tournament,
      bool isChecked,
      List<Tournament> past,
      ) {
    isChecked = true;
    past.add(tournament);
    return isChecked;
  }

  bool addInProgressTournament(
      Tournament tournament,
      bool isChecked,
      List<Tournament> inProgress,
      ) {
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
      pouleList.add(
        Poule(
          name: currentName,
          matchList: getListMatch(valueMap['matchs'] as List<Object?>),
          playerList: getPlayerList(valueMap['players'] as List<Object?>),
        ),
      );
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
        location: "${map['location']}",
      );
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
    List<MatchTournament> semiList = getMatchListMap('semiFinal', mapValue);
    List<MatchTournament> quarterList = getMatchListMap('quartFinal', mapValue);

    MatchTournament smallFinall = getFinalMatch('smallFinalMatch', mapValue);
    MatchTournament finale = getFinalMatch('finalMatch', mapValue);

    return EndTournament(
      finalMatch: finale,
      smallFinalMatch: smallFinall,
      semiFinalist: semiList,
      quarterFinalList: quarterList,
    );
  }

  List<MatchTournament> getMatchListMap(
      String key,
      Map<Object?, Object?> mapValue,
      ) {
    if (mapValue[key] == null) {
      return [];
    }

    List<Object?> objectList = mapValue[key] as List<Object?>;
    List<MatchTournament> matchList = [];
    objectList.forEach((currentElem) {
      Map<Object?, Object?> valueMap = currentElem as Map<Object?, Object?>;
      MatchTournament currentMatch = MatchTournament(
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

  void navigateToDetailPage(
      BuildContext context,
      Tournament tournament,
      bool inProgress,
      ) {
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

  @override
  void dispose() {
    _tournoisSub?.cancel();
    super.dispose();
  }
}
