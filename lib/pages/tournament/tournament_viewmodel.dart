import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament.dart';
import 'package:tournament_management/repositories/tournament_repository.dart';

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
  final TournamentRepository _repository;

  TournamentState _state = const TournamentState();
  TournamentState get state => _state;

  StreamSubscription<DatabaseEvent>? _tournoisSub;

  // On garde les listes d'origine (utile si d'autres écrans les utilisent plus tard)
  List<Tournament> inProgressTournament = [];
  List<Tournament> pastTournaments = [];
  List<Tournament> cancelNotPlayedTournaments = [];
  List<Tournament> tournaments = [];

  TournamentViewmodel({TournamentRepository? repository})
      : _repository = repository ?? TournamentRepository();

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

    _tournoisSub = _repository.watchAll().listen(
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

    final snapshot = await _repository.fetchAllSnapshot();
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
      if (value is! Map) return;

      // On réutilise le parsing tolérant de Tournament.fromJson plutôt que
      // de dupliquer un parsing manuel avec des cast non sécurisés : un
      // champ manquant ou une variante de clé (ex: pouleList/matchs vs
      // matchList) ne fait plus planter le chargement de la liste.
      final Tournament tournament;
      try {
        tournament = Tournament.fromJson(
          Map<String, dynamic>.from(value)..['id'] = key.toString(),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Tournoi $key ignoré (parsing impossible) : $e');
        }
        return;
      }

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

  /// Classe le tournoi dans une seule des trois catégories, dans cet ordre
  /// de priorité : annulé (action explicite du créateur) > en cours (finale
  /// pas encore jouée) > terminé (finale jouée avec les deux joueurs
  /// renseignés).
  void retrieveCurrentUserData(
      Tournament tournament,
      List<Tournament> inProgress,
      List<Tournament> past,
      List<Tournament> cancel,
      ) {
    tournaments.add(tournament);

    if (tournament.isCancelled) {
      cancel.add(tournament);
      return;
    }

    if (tournament.finalMatchList.finalMatch.score.isEmpty) {
      inProgress.add(tournament);
      return;
    }

    if (tournament.finalMatchList.finalMatch.player1.isNotEmpty &&
        tournament.finalMatchList.finalMatch.player2.isNotEmpty) {
      past.add(tournament);
      return;
    }

    if (kDebugMode) print("tournament not taken : $tournament");
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
