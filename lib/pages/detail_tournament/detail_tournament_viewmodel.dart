import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/graphView/GraphView.dart';
import 'package:tournament_management/models/bracket_format.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/models/tournament_phase.dart';
import 'package:tournament_management/repositories/tournament_repository.dart';
import 'package:tournament_management/utils.dart';
import 'package:tournament_management/widgets/tournament_node.dart';

class DetailTournamentState {
  final int tabIndex;
  final bool isLoading;
  final bool isOwner;
  final String? errorMessage;


  final Tournament? tournament;
  final String? currentUserEmail;
  final bool isDeleting;
  final bool deleteSuccess;
  final String? selectedPoule;

  const DetailTournamentState({
    this.tabIndex = 0,
    this.isLoading = false,
    this.isOwner = false,
    this.errorMessage,
    this.tournament,
    this.currentUserEmail,
    this.isDeleting = false,
    this.deleteSuccess = false,
    this.selectedPoule,
  });

  DetailTournamentState copyWith({
    int? tabIndex,
    bool? isLoading,
    bool? isOwner,
    String? errorMessage,
    Tournament? tournament,
    String? currentUserEmail,
    bool? isDeleting,
    bool? deleteSuccess,
    String? selectedPoule,
  }) {
    return DetailTournamentState(
      tabIndex: tabIndex ?? this.tabIndex,
      isLoading: isLoading ?? this.isLoading,
      isOwner: isOwner ?? this.isOwner,
      errorMessage: errorMessage,
      tournament: tournament ?? this.tournament,
      currentUserEmail: currentUserEmail ?? this.currentUserEmail,
      isDeleting: isDeleting ?? this.isDeleting,
      deleteSuccess: deleteSuccess ?? this.deleteSuccess,
      selectedPoule: selectedPoule ?? this.selectedPoule,
    );
  }


  /// Vrai si l'utilisateur courant est le créateur du tournoi et que la
  /// finale a été jouée (même règle que le bouton de suppression affiché
  /// dans la vue, voir detail_tournament.dart / _canShowDeleteButton).
  bool get canDeleteTournament {
    final t = tournament;
    final email = currentUserEmail;
    if (t == null || email == null) return false;

    return t.createdBy == email && t.finalMatchList.finalMatch.score.isNotEmpty;
  }
}




// --- INTENTS --- //

abstract class DetailTournamentIntent {
  const DetailTournamentIntent();
}

class ChangeTabIntent extends DetailTournamentIntent {
  final int index;
  const ChangeTabIntent(this.index);
}

class GeneratePoolsIntent extends DetailTournamentIntent {
  const GeneratePoolsIntent();
}

class DetailTournamentIntentDeleteConfirmed extends DetailTournamentIntent {
  const DetailTournamentIntentDeleteConfirmed();
}

class DetailTournamentIntentCancelConfirmed extends DetailTournamentIntent {
  const DetailTournamentIntentCancelConfirmed();
}

class SelectPouleIntent extends DetailTournamentIntent {
  final String pouleName;
  const SelectPouleIntent(this.pouleName);
}



class DetailTournamentViewModel extends ChangeNotifier {
  final Tournament tournament;
  final bool inProgress;
  final TournamentRepository _repository;

  /// Nombre de matchs de quart de finale requis pour construire l'arbre
  /// (4 matchs de quart -> 8 joueurs, qui alimentent les 2 demies).
  static const int _requiredQuarterFinals = 4;

  DetailTournamentState _state = const DetailTournamentState();
  DetailTournamentState get state => _state;

  DetailTournamentViewModel({
    required this.tournament,
    required this.inProgress,
    TournamentRepository? repository,
  }) : _repository = repository ?? TournamentRepository();


  Future<void> init() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    _state = _state.copyWith(currentUserEmail: email, isLoading: true);
    notifyListeners();
    _state = _state.copyWith(tournament: tournament, isLoading: false);
    notifyListeners();
  }


  void _setState(DetailTournamentState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(DetailTournamentIntent intent) async {
    if (intent is ChangeTabIntent) {
      _setState(_state.copyWith(tabIndex: intent.index));
    } else if (intent is GeneratePoolsIntent) {
      await _handleGeneratePools();
    } else if (intent is DetailTournamentIntentDeleteConfirmed) {
      _handleDeleteConfirmed();
    } else if (intent is DetailTournamentIntentCancelConfirmed) {
      await _handleCancelConfirmed();
    } else if (intent is SelectPouleIntent) {
      _setState(_state.copyWith(selectedPoule: intent.pouleName));
    }
    // plus tard : autres intents
  }

  Future<void> _handleDeleteConfirmed() async {
    final t = _state.tournament;
    if (t == null) return;
    if (_state.isDeleting) return;

    _setState(_state.copyWith(isDeleting: true, errorMessage: null));

    try {
      await _repository.deleteTournament(t.id);
      _setState(_state.copyWith(isDeleting: false, deleteSuccess: true));
    } catch (e) {
      _setState(_state.copyWith(isDeleting: false, errorMessage: "Erreur suppression : $e"));
    }
  }

  Future<void> _handleCancelConfirmed() async {
    final t = _state.tournament;
    if (t == null) return;

    _setState(_state.copyWith(errorMessage: null));

    try {
      await _repository.setCancelled(t.id, true);
      t.isCancelled = true;
      _setState(_state.copyWith(tournament: t));
    } catch (e) {
      _setState(_state.copyWith(errorMessage: "Erreur lors de l'annulation : $e"));
    }
  }




  Future<void> _handleGeneratePools() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      if (tournament.bracketFormat == BracketFormat.directBracket) {
        await startDirectBracket();
      } else {
        // Génère les poules à partir des participants du tournoi
        await generatePoolsAndUpdateTournament();
      }

      _setState(_state.copyWith(isLoading: false));
    } catch (e) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: "Erreur lors de la génération du tableau : $e",
        ),
      );
    }
  }

  Future<void> generatePoolsAndUpdateTournament() async {
    // Génère les poules à partir des participants du tournoi
    final List<Poule> poules = generatePools(tournament.participants);

    // Met à jour le modèle en mémoire
    tournament.pouleList
      ..clear()
      ..addAll(poules);

    notifyListeners();
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
          date: calculateDate("poule"),
          location: tournament.location,
        );
        matches.add(match);
      }
    }
    return matches;
  }

  String calculateDate(String phase) {
    DateTime startDate =
    DateFormat("dd/MM/yyyy").parse(tournament.tournamentDate.start!);
    DateTime endDate =
    DateFormat("dd/MM/yyyy").parse(tournament.tournamentDate.end!);

    int totalDays = endDate.difference(startDate).inDays;
    if (totalDays < 3) {
      throw Exception("Le tournoi doit durer au moins 3 jours.");
    }

    // Répartition des jours
    int phaseGroupDays = (totalDays * 0.6).floor();
    int quarterFinalsDays = (totalDays * 0.2).floor();
    int semiFinalsDays = (totalDays * 0.15).floor();
    int finalsDays =
        totalDays - (phaseGroupDays + quarterFinalsDays + semiFinalsDays);

    DateTime startPoule = startDate;
    DateTime startQuarter = startPoule.add(Duration(days: phaseGroupDays));
    DateTime startSemi =
    startQuarter.add(Duration(days: quarterFinalsDays));
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

  Future<void> _savePoolsToFirebase(List<Poule> poules) async {
    final Map<String, dynamic> allPoulesData = {};
    for (final poule in poules) {
      final data = Map<String, dynamic>.from(poule.toJson());
      data.remove('name');
      allPoulesData[poule.name] = data;
    }

    await _repository.savePools(tournament.id, allPoulesData);
  }

  // --- Tableau direct (format sans poules) ---

  /// Génère le 1er tour du tableau direct, à partir du nombre de
  /// participants et du choix de repêchage (voir [computeFirstRoundPlan]).
  Future<void> startDirectBracket() async {
    final plan = computeFirstRoundPlan(
      tournament.participants.length,
      useRepechage: tournament.useRepechage,
    );

    final shuffled = List<String>.from(tournament.participants)..shuffle();
    final round1Players = shuffled.sublist(0, plan.firstRoundPlayers);

    tournament.finalMatchList.directBracketRounds = [_pairIntoMatches(round1Players)];

    await _repository.saveDirectBracketRounds(
      tournament.id,
      tournament.finalMatchList.directBracketRounds,
    );

    notifyListeners();
  }

  List<MatchTournament> _pairIntoMatches(List<String> players) {
    final matches = <MatchTournament>[];
    for (int i = 0; i < players.length; i += 2) {
      matches.add(MatchTournament(
        player1: players[i],
        player2: players[i + 1],
        score: '',
        date: calculateDate("poule"),
        location: tournament.location,
      ));
    }
    return matches;
  }

  /// Détermine la phase applicable à un match du tableau direct pour
  /// choisir les bonnes [MatchRules] : les tours normaux utilisent les
  /// règles par défaut (comme les poules), le dernier tour (2 matchs, sur
  /// le point d'être promu vers les demies) utilise les règles de la
  /// phase finale.
  TournamentPhase phaseForDirectBracketMatch(MatchTournament match) {
    for (final round in tournament.finalMatchList.directBracketRounds) {
      final found = round.any((m) =>
          (m.player1 == match.player1 && m.player2 == match.player2) ||
          (m.player1 == match.player2 && m.player2 == match.player1));
      if (found) {
        return round.length == 2
            ? TournamentPhase.SEMI_FINAL
            : TournamentPhase.GROUP;
      }
    }
    return TournamentPhase.GROUP;
  }

  /// Enregistre le score d'un match du tableau direct, et fait progresser
  /// le tableau d'un cran si le tour courant vient d'être complété.
  Future<void> submitDirectBracketMatchScore(MatchTournament newMatch) async {
    final rounds = tournament.finalMatchList.directBracketRounds;

    int? roundIndex;
    int? matchIndex;
    for (int r = 0; r < rounds.length; r++) {
      final idx = rounds[r].indexWhere((m) =>
          (m.player1 == newMatch.player1 && m.player2 == newMatch.player2) ||
          (m.player1 == newMatch.player2 && m.player2 == newMatch.player1));
      if (idx != -1) {
        roundIndex = r;
        matchIndex = idx;
        break;
      }
    }

    if (roundIndex == null || matchIndex == null) return;

    final ref = _repository
        .tournamentRef(tournament.id)
        .child('directBracketRounds')
        .child(roundIndex.toString())
        .child(matchIndex.toString());

    await _repository.updateBracketMatch(ref, newMatch);

    rounds[roundIndex][matchIndex] = newMatch;

    await _maybeAdvanceDirectBracket();

    notifyListeners();
  }

  /// Fait progresser le tableau direct d'un cran si le tour courant vient
  /// d'être entièrement joué : génère le tour suivant (avec byes/repêchage
  /// uniquement lors de la transition 1er -> 2e tour), ou promeut le
  /// dernier tour (2 matchs) vers les demies pour réutiliser la logique
  /// existante de génération finale / petite finale.
  Future<void> _maybeAdvanceDirectBracket() async {
    final rounds = tournament.finalMatchList.directBracketRounds;
    if (rounds.isEmpty) return;

    final currentRoundIndex = rounds.length - 1;
    final currentRound = rounds[currentRoundIndex];

    if (!_allPlayed(currentRound)) return;

    if (currentRound.length == 2) {
      if (tournament.finalMatchList.semiFinalist.isEmpty) {
        tournament.finalMatchList.semiFinalist =
            List<MatchTournament>.from(currentRound);
        await _repository.saveSemiFinals(
          tournament.id,
          tournament.finalMatchList.semiFinalist,
        );
        // Réutilise la logique existante : détecte que les demies sont
        // désormais jouées et enchaîne sur la génération de la finale.
        _maybeAdvanceBracket();
      }
      return;
    }

    final qualifiers = <String>[];

    if (currentRoundIndex == 0) {
      final winners = currentRound.map(getWinner).toList();

      final playedPlayers = <String>{};
      for (final m in currentRound) {
        playedPlayers.add(m.player1);
        playedPlayers.add(m.player2);
      }
      final byePlayers = tournament.participants
          .where((p) => !playedPlayers.contains(p))
          .toList();

      qualifiers.addAll(winners);
      qualifiers.addAll(byePlayers);

      if (tournament.useRepechage) {
        final plan = computeFirstRoundPlan(
          tournament.participants.length,
          useRepechage: true,
        );
        if (plan.repechageNeeded > 0) {
          final losersRanked = _rankLosersForRepechage(currentRound);
          qualifiers.addAll(losersRanked.take(plan.repechageNeeded));
        }
      }
    } else {
      qualifiers.addAll(currentRound.map(getWinner));
    }

    final nextRound = _pairIntoMatches(qualifiers);
    tournament.finalMatchList.directBracketRounds = [...rounds, nextRound];

    await _repository.saveDirectBracketRounds(
      tournament.id,
      tournament.finalMatchList.directBracketRounds,
    );
  }

  /// Classe les perdants d'un tour pour le repêchage : d'abord par nombre
  /// de sets gagnés dans leur défaite (plus il y en a, mieux classé), puis
  /// par nombre de points marqués dans le(s) set(s) perdu(s) (départage).
  /// En format "1 set gagnant", le 1er critère est toujours à égalité et
  /// le classement se fait entièrement sur le 2e.
  List<String> _rankLosersForRepechage(List<MatchTournament> round) {
    final entries = round.map((m) {
      final winner = getWinner(m);
      final loser = m.player1 == winner ? m.player2 : m.player1;
      return MapEntry(loser, m);
    }).toList();

    entries.sort((a, b) {
      final setsA = _setsWonByPlayer(a.value, a.key);
      final setsB = _setsWonByPlayer(b.value, b.key);
      if (setsA != setsB) return setsB.compareTo(setsA);

      final pointsA = _pointsInLostSets(a.value, a.key);
      final pointsB = _pointsInLostSets(b.value, b.key);
      return pointsB.compareTo(pointsA);
    });

    return entries.map((e) => e.key).toList();
  }

  int _setsWonByPlayer(MatchTournament match, String player) {
    final sets = match.score.split(';');
    int count = 0;
    for (final s in sets) {
      final parts = s.trim().split('-');
      if (parts.length != 2) continue;
      final p1 = int.tryParse(parts[0]) ?? 0;
      final p2 = int.tryParse(parts[1]) ?? 0;
      final isPlayer1 = match.player1 == player;
      final playerScore = isPlayer1 ? p1 : p2;
      final opponentScore = isPlayer1 ? p2 : p1;
      if (playerScore > opponentScore) count++;
    }
    return count;
  }

  int _pointsInLostSets(MatchTournament match, String player) {
    final sets = match.score.split(';');
    int total = 0;
    for (final s in sets) {
      final parts = s.trim().split('-');
      if (parts.length != 2) continue;
      final p1 = int.tryParse(parts[0]) ?? 0;
      final p2 = int.tryParse(parts[1]) ?? 0;
      final isPlayer1 = match.player1 == player;
      final playerScore = isPlayer1 ? p1 : p2;
      final opponentScore = isPlayer1 ? p2 : p1;
      if (playerScore < opponentScore) {
        total += playerScore;
      }
    }
    return total;
  }

  // --- Phase de poules : lecture / saisie de score ---

  List<MatchTournament> getMatchListFromPoule(String pouleName) {
    final pouleList = tournament.pouleList;
    if (pouleList.isEmpty) return [];
    final matches = pouleList.where((element) => element.name == pouleName);
    if (matches.isEmpty) return [];
    return matches.first.matchList;
  }

  bool isAllMatchPlayed() {
    for (var poule in tournament.pouleList) {
      for (var match in poule.matchList) {
        if (match.score.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> checkMatchExists(
      String player1,
      String player2,
      DatabaseReference databaseReference,
      ) => _repository.pouleMatchExists(databaseReference, player1, player2);

  /// Enregistre le score d'un match de poule (Firebase + modèle local), et
  /// indique si tous les matchs de la poule sont désormais joués (pour que
  /// la vue puisse proposer de passer à la phase suivante).
  Future<bool> submitPouleMatchScore(
      String pouleName,
      DatabaseReference selectedPouleRef,
      MatchTournament newMatch,
      ) async {
    await updateMatch(selectedPouleRef, newMatch);

    tournament.updatePoule(
      pouleName,
      newMatch.player1,
      newMatch.player2,
      newMatch.score,
    );

    notifyListeners();

    return isAllMatchPlayed();
  }

  /// Calcule les quarts de finale à partir du classement de chaque poule
  /// et les sauvegarde sur Firebase. À appeler une fois que
  /// [isAllMatchPlayed] renvoie vrai.
  Future<void> generateQuarterFinalsFromPoules() async {
    Map<String, List<String>> pouleRankings = {};

    for (var poule in tournament.pouleList) {
      var wins = _calculateWins(poule.matchList, poule.playerList);
      pouleRankings[poule.name] = _rankPlayers(wins);
    }

    tournament.finalMatchList.quarterFinalList =
        _createQuarterFinalBracket(pouleRankings);

    await _repository.saveQuarterFinals(
      tournament.id,
      tournament.finalMatchList.quarterFinalList,
    );

    notifyListeners();
  }

  Map<String, int> _calculateWins(
      List<MatchTournament> matches, List<String> players) {
    Map<String, int> wins = Map.fromIterable(players, value: (_) => 0);

    for (var match in matches) {
      if (match.score.isEmpty) continue;

      var scoreParts = match.score.split(';');
      int player1Wins = 0;
      int player2Wins = 0;

      for (var score in scoreParts) {
        var setScores = score.split('-');
        if (setScores.length == 2) {
          int player1Score = int.tryParse(setScores[0]) ?? 0;
          int player2Score = int.tryParse(setScores[1]) ?? 0;

          if (player1Score > player2Score) {
            player1Wins++;
          } else if (player2Score > player1Score) {
            player2Wins++;
          }
        }
      }

      if (player1Wins > player2Wins) {
        wins[match.player1] = (wins[match.player1] ?? 0) + 1;
      } else if (player2Wins > player1Wins) {
        wins[match.player2] = (wins[match.player2] ?? 0) + 1;
      }
    }

    return wins;
  }

  List<String> _rankPlayers(Map<String, int> wins) {
    var sortedEntries = wins.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.map((e) => e.key).toList();
  }

  List<MatchTournament> _createQuarterFinalBracket(
      Map<String, List<String>> pouleRankings,
      ) {
    return [
      MatchTournament(
        player1: pouleRankings['A']![0],
        player2: pouleRankings['B']![1],
        score: '',
        date: calculateDate("1/4"),
        location: tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['C']![0],
        player2: pouleRankings['D']![1],
        score: '',
        date: calculateDate("1/4"),
        location: tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['B']![0],
        player2: pouleRankings['A']![1],
        score: '',
        date: calculateDate("1/4"),
        location: tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['D']![0],
        player2: pouleRankings['C']![1],
        score: '',
        date: calculateDate("1/4"),
        location: tournament.location,
      ),
    ];
  }

  Future<void> updateMatch(
      DatabaseReference selectedPouleRef, MatchTournament newMatch) =>
      _repository.updatePouleMatch(selectedPouleRef, newMatch);

  // --- Phase finale : quarts / demies / finale / petite finale ---

  /// Prêt à afficher l'arbre (demies/finale) : selon le format, une fois
  /// les quarts générés (poules), ou une fois le tableau direct promu
  /// jusqu'aux demies (tableau direct).
  bool get isBracketReady {
    if (tournament.bracketFormat == BracketFormat.directBracket) {
      return tournament.finalMatchList.semiFinalist.isNotEmpty;
    }
    return tournament.finalMatchList.quarterFinalList.length >= _requiredQuarterFinals;
  }

  DatabaseReference getTournamentRef(MatchTournament match) {
    final tournamentRef = _repository.tournamentRef(tournament.id);
    final end = tournament.finalMatchList;

    final quarterIndex = tournament.getIndex(end.quarterFinalList, match);
    if (quarterIndex != -1) {
      return tournamentRef.child("quartFinal").child(quarterIndex.toString());
    }

    final semiIndex = tournament.getIndex(end.semiFinalist, match);
    if (semiIndex != -1) {
      return tournamentRef.child("semiFinal").child(semiIndex.toString());
    }

    if (_isSameMatch(end.smallFinalMatch, match)) {
      return tournamentRef.child('smallFinalMatch');
    }

    // Sinon on considère que c'est la finale
    return tournamentRef.child('finalMatch');
  }

  /// Détermine la phase d'un match (par paire de joueurs, même détection
  /// que [getTournamentRef]), pour savoir quelles [MatchRules] appliquer
  /// (voir [Tournament.rules] / [TournamentRules.rulesFor]).
  TournamentPhase phaseFor(MatchTournament match) {
    final end = tournament.finalMatchList;

    if (tournament.getIndex(end.quarterFinalList, match) != -1) {
      return TournamentPhase.QUARTER_FINAL;
    }
    if (tournament.getIndex(end.semiFinalist, match) != -1) {
      return TournamentPhase.SEMI_FINAL;
    }
    if (_isSameMatch(end.smallFinalMatch, match)) {
      return TournamentPhase.SMALL_FINAL;
    }
    return TournamentPhase.FINAL;
  }

  List<String> getPlayerList(List<MatchTournament> listMatch) {
    List<String> playerList = [];
    for (MatchTournament match in listMatch) {
      playerList.add(match.player1);
      playerList.add(match.player2);
    }
    return playerList;
  }

  bool hasNotEmptyElements(List<MatchTournament> list) {
    for (MatchTournament currentMatch in list) {
      if (currentMatch.score.isEmpty) return true;
    }
    return false;
  }

  String retrievePlayer(String selectedPlayer) {
    final end = tournament.finalMatchList;
    String player = "";
    if (hasNotEmptyElements(end.quarterFinalList)) {
      for (MatchTournament match in end.quarterFinalList) {
        if (match.player1 == selectedPlayer) {
          player = match.player2;
          continue;
        } else if (match.player2 == selectedPlayer) {
          player = match.player1;
          continue;
        }
      }
    } else if (hasNotEmptyElements(end.semiFinalist)) {
      for (MatchTournament match in end.semiFinalist) {
        if (match.player1 == selectedPlayer) {
          player = match.player2;
          continue;
        } else if (match.player2 == selectedPlayer) {
          player = match.player1;
          continue;
        }
      }
    } else if (end.finalMatch.player1 == selectedPlayer) {
      player = end.finalMatch.player2;
    } else {
      player = end.finalMatch.player1;
    }
    return player;
  }

  /// Enregistre le score d'un match de la phase finale (quart / demie /
  /// finale / petite finale) : écrit sur Firebase au bon endroit, met à
  /// jour le modèle local, puis fait progresser l'arbre d'un cran si la
  /// phase courante vient d'être complétée.
  Future<void> submitBracketMatchScore(MatchTournament newMatch) async {
    final ref = getTournamentRef(newMatch);
    await updateMatchGraph(ref, newMatch);

    _applyScoreToCorrectPhase(newMatch);
    _maybeAdvanceBracket();

    notifyListeners();
  }

  Future<void> updateMatchGraph(
      DatabaseReference endTournamentRef, MatchTournament newMatch) =>
      _repository.updateBracketMatch(endTournamentRef, newMatch);

  /// Met à jour le modèle local dans la bonne liste (quart / demie / finale)
  /// selon la phase réelle du match, en réutilisant la même détection que
  /// [getTournamentRef] (comparaison par joueurs, score/date ignorés).
  void _applyScoreToCorrectPhase(MatchTournament newMatch) {
    final end = tournament.finalMatchList;

    final quarterIndex = tournament.getIndex(end.quarterFinalList, newMatch);
    if (quarterIndex != -1) {
      tournament.upsertQuarterFinalMatch(newMatch);
      return;
    }

    final semiIndex = tournament.getIndex(end.semiFinalist, newMatch);
    if (semiIndex != -1) {
      tournament.upsertSemiFinalMatch(newMatch);
      return;
    }

    if (_isSameMatch(end.smallFinalMatch, newMatch)) {
      tournament.updateSmallFinaleMatch(newMatch);
      return;
    }

    tournament.updateFinaleMatch(newMatch);
  }

  /// Égalité logique entre deux matchs uniques (finale / petite finale).
  /// Comparaison par paire de joueurs uniquement (ordre indifférent), pour
  /// la même raison que dans [Tournament.getIndex] : la date n'est pas un
  /// identifiant stable entre la génération du match et la saisie du score.
  bool _isSameMatch(MatchTournament a, MatchTournament b) {
    return (a.player1 == b.player1 && a.player2 == b.player2) ||
        (a.player1 == b.player2 && a.player2 == b.player1);
  }

  bool _allPlayed(List<MatchTournament> matches) {
    if (matches.isEmpty) return false;
    return matches.every((m) => m.score.isNotEmpty);
  }

  /// Fait progresser l'arbre d'un cran si la phase courante vient d'être
  /// complétée : quarts terminés -> génère les demies ; demies terminées
  /// -> génère la finale et la petite finale.
  void _maybeAdvanceBracket() {
    final end = tournament.finalMatchList;

    if (end.semiFinalist.isEmpty && _allPlayed(end.quarterFinalList)) {
      _generateSemiFinals();
      return;
    }

    if (end.finalMatch.player1.isEmpty &&
        end.semiFinalist.isNotEmpty &&
        _allPlayed(end.semiFinalist)) {
      _generateFinal();
    }
  }

  void _generateSemiFinals() {
    final quarters = tournament.finalMatchList.quarterFinalList;

    final semi0 = MatchTournament(
      player1: getWinner(quarters[0]),
      player2: getWinner(quarters[1]),
      score: '',
      date: calculateDate("1/2"),
      location: tournament.location,
    );
    final semi1 = MatchTournament(
      player1: getWinner(quarters[2]),
      player2: getWinner(quarters[3]),
      score: '',
      date: calculateDate("1/2"),
      location: tournament.location,
    );

    tournament.finalMatchList.semiFinalist = [semi0, semi1];

    _repository.saveSemiFinals(
      tournament.id,
      tournament.finalMatchList.semiFinalist,
    );
  }

  void _generateFinal() {
    final semis = tournament.finalMatchList.semiFinalist;

    final finalMatch = MatchTournament(
      player1: getWinner(semis[0]),
      player2: getWinner(semis[1]),
      score: '',
      date: calculateDate("finale"),
      location: tournament.location,
    );

    final smallFinalMatch = MatchTournament(
      player1: getLoser(semis[0]),
      player2: getLoser(semis[1]),
      score: '',
      date: calculateDate("finale"),
      location: tournament.location,
    );

    tournament.updateFinaleMatch(finalMatch);
    tournament.updateSmallFinaleMatch(smallFinalMatch);

    _repository.saveFinalAndSmallFinal(tournament.id, finalMatch, smallFinalMatch);
  }

  // --- Construction de l'arbre (GraphView) ---

  Graph createTournamentTree() {
    final endTournament = tournament.finalMatchList;
    final Graph graph = Graph()..isTree = true;

    final TournamentNode winnerNode =
    TournamentNode(0, "Winner: ${getWinner(endTournament.finalMatch)}");

    final TournamentNode finalPlayer1Node = TournamentNode(
        1, endTournament.finalMatch.player1, match: endTournament.finalMatch);

    final TournamentNode finalPlayer2Node = TournamentNode(
        2, endTournament.finalMatch.player2, match: endTournament.finalMatch);

    final TournamentNode semiPlayer1Node =
    _getTournamentNode(3, endTournament, 0, TournamentPhase.SEMI_FINAL, true);
    final TournamentNode semiPlayer2Node =
    _getTournamentNode(4, endTournament, 0, TournamentPhase.SEMI_FINAL, false);
    final TournamentNode semiPlayer3Node =
    _getTournamentNode(5, endTournament, 1, TournamentPhase.SEMI_FINAL, true);
    final TournamentNode semiPlayer4Node =
    _getTournamentNode(6, endTournament, 1, TournamentPhase.SEMI_FINAL, false);

    final TournamentNode quarterPlayer1Node = _getTournamentNode(
        7, endTournament, 0, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer2Node = _getTournamentNode(
        8, endTournament, 0, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer3Node = _getTournamentNode(
        9, endTournament, 1, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer4Node = _getTournamentNode(
        10, endTournament, 1, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer5Node = _getTournamentNode(
        11, endTournament, 2, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer6Node = _getTournamentNode(
        12, endTournament, 2, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer7Node = _getTournamentNode(
        13, endTournament, 3, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer8Node = _getTournamentNode(
        14, endTournament, 3, TournamentPhase.QUARTER_FINAL, false);

    graph.addEdge(winnerNode, finalPlayer1Node);
    graph.addEdge(winnerNode, finalPlayer2Node);

    graph.addEdge(finalPlayer1Node, semiPlayer1Node);
    graph.addEdge(finalPlayer1Node, semiPlayer2Node);
    graph.addEdge(finalPlayer2Node, semiPlayer3Node);
    graph.addEdge(finalPlayer2Node, semiPlayer4Node);

    graph.addEdge(semiPlayer1Node, quarterPlayer1Node);
    graph.addEdge(semiPlayer1Node, quarterPlayer2Node);
    graph.addEdge(semiPlayer2Node, quarterPlayer3Node);
    graph.addEdge(semiPlayer2Node, quarterPlayer4Node);
    graph.addEdge(semiPlayer3Node, quarterPlayer5Node);
    graph.addEdge(semiPlayer3Node, quarterPlayer6Node);
    graph.addEdge(semiPlayer4Node, quarterPlayer7Node);
    graph.addEdge(semiPlayer4Node, quarterPlayer8Node);

    return graph;
  }

  TournamentNode _getTournamentNode(
      int id,
      EndTournament endTournament,
      int index,
      TournamentPhase phase,
      bool player1,
      ) {
    switch (phase) {
      case TournamentPhase.FINAL:
        return _buildNodeFromMatch(endTournament.finalMatch, id, player1);
      case TournamentPhase.SMALL_FINAL:
        return _buildNodeFromMatch(endTournament.smallFinalMatch, id, player1);
      case TournamentPhase.SEMI_FINAL:
        if (index >= 0 && index < endTournament.semiFinalist.length) {
          final m = endTournament.semiFinalist[index];
          return _buildNodeFromMatch(m, id, player1);
        }
        throw RangeError('index demi-finale hors bornes: $index');
      case TournamentPhase.QUARTER_FINAL:
        if (index >= 0 && index < endTournament.quarterFinalList.length) {
          final m = endTournament.quarterFinalList[index];
          return _buildNodeFromMatch(m, id, player1);
        }
        throw RangeError('index quart de finale hors bornes: $index');
      case TournamentPhase.GROUP:
        throw StateError(
            'La phase GROUP n\'a pas de TournamentNode dans EndTournament');
    }
  }

  TournamentNode _buildNodeFromMatch(
      MatchTournament m, int id, bool isPlayer1) {
    final name = isPlayer1 ? m.player1 : m.player2;
    return TournamentNode(id, name, match: m);
  }

  // --- Arbre pour le tableau direct (profondeur variable) ---

  int _nodeIdCounter = 0;

  int _nextNodeId() {
    final id = _nodeIdCounter;
    _nodeIdCounter++;
    return id;
  }

  /// Construit l'arbre visuel pour un tournoi en tableau direct, dont la
  /// profondeur (nombre de tours avant les demies) est variable selon le
  /// nombre de participants — contrairement à [createTournamentTree], câblé
  /// en dur sur la forme fixe quarts(4)/demies(2) du format poules.
  ///
  /// Remonte récursivement l'historique de chaque demi-finaliste à travers
  /// [EndTournament.directBracketRounds] jusqu'au 1er tour. Les byes et
  /// repêchés (qui n'ont pas de match à un tour donné) deviennent
  /// naturellement des feuilles sans enfant, sans cas particulier à gérer.
  Graph createDirectBracketTree() {
    _nodeIdCounter = 0;
    final endTournament = tournament.finalMatchList;
    final Graph graph = Graph()..isTree = true;

    final TournamentNode winnerNode = TournamentNode(
        _nextNodeId(), "Winner: ${getWinner(endTournament.finalMatch)}");

    final TournamentNode finalPlayer1Node = TournamentNode(
        _nextNodeId(), endTournament.finalMatch.player1,
        match: endTournament.finalMatch);
    final TournamentNode finalPlayer2Node = TournamentNode(
        _nextNodeId(), endTournament.finalMatch.player2,
        match: endTournament.finalMatch);

    graph.addEdge(winnerNode, finalPlayer1Node);
    graph.addEdge(winnerNode, finalPlayer2Node);

    _attachDirectBracketSemiSubtree(graph, finalPlayer1Node, 0, endTournament);
    _attachDirectBracketSemiSubtree(graph, finalPlayer2Node, 1, endTournament);

    return graph;
  }

  /// Rattache au graphe le sous-arbre du demi-finaliste [semiIndex] (0 ou
  /// 1). Le dernier tour de [EndTournament.directBracketRounds] EST
  /// [EndTournament.semiFinalist] (promu tel quel une fois joué, voir
  /// [_maybeAdvanceDirectBracket]) : la remontée démarre donc un cran
  /// avant lui, pour ne pas représenter ce tour deux fois.
  void _attachDirectBracketSemiSubtree(
      Graph graph,
      TournamentNode parentNode,
      int semiIndex,
      EndTournament endTournament,
      ) {
    if (semiIndex >= endTournament.semiFinalist.length) return;
    final semiMatch = endTournament.semiFinalist[semiIndex];
    final rounds = endTournament.directBracketRounds;

    final searchFromIndex = rounds.length - 2;

    final p1Node = _buildDirectBracketPlayerSubtree(
        graph, semiMatch.player1, searchFromIndex, rounds, semiMatch);
    final p2Node = _buildDirectBracketPlayerSubtree(
        graph, semiMatch.player2, searchFromIndex, rounds, semiMatch);

    graph.addEdge(parentNode, p1Node);
    graph.addEdge(parentNode, p2Node);
  }

  /// Construit récursivement le sous-arbre menant à [playerName], en
  /// remontant les tours de [rounds] depuis [roundIndex] jusqu'au 1er tour
  /// (index 0). [fallbackMatch] est le match utilisé pour ce nœud (celui
  /// où [playerName] apparaît au tour *suivant*, pas encore trouvé ici).
  ///
  /// Si [playerName] n'apparaît pas au tour [roundIndex] (bye ou
  /// repêché à ce tour précis), le nœud devient une feuille sans enfant :
  /// aucun cas particulier à gérer, la récursion s'arrête naturellement.
  TournamentNode _buildDirectBracketPlayerSubtree(
      Graph graph,
      String playerName,
      int roundIndex,
      List<List<MatchTournament>> rounds,
      MatchTournament fallbackMatch,
      ) {
    final node = TournamentNode(_nextNodeId(), playerName, match: fallbackMatch);

    if (roundIndex < 0) return node;

    MatchTournament? originMatch;
    for (final m in rounds[roundIndex]) {
      if (m.player1 == playerName || m.player2 == playerName) {
        originMatch = m;
        break;
      }
    }

    if (originMatch == null) {
      // Bye ou repêché à ce tour : rien à tracer plus loin.
      return node;
    }

    final p1Sub = _buildDirectBracketPlayerSubtree(
        graph, originMatch.player1, roundIndex - 1, rounds, originMatch);
    final p2Sub = _buildDirectBracketPlayerSubtree(
        graph, originMatch.player2, roundIndex - 1, rounds, originMatch);

    graph.addEdge(node, p1Sub);
    graph.addEdge(node, p2Sub);

    return node;
  }
}
