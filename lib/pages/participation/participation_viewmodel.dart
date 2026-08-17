import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/participation_model.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/repositories/tournament_repository.dart';

/// --- STATE --- ///
class ParticipationState {
  final bool isLoadingUpcoming;
  final bool isLoadingResults;
  final String? errorUpcoming;
  final String? errorResults;
  final List<ParticipationModel> upcoming;
  final List<ParticipationModel> results;

  const ParticipationState({
    this.isLoadingUpcoming = false,
    this.isLoadingResults = false,
    this.errorUpcoming,
    this.errorResults,
    this.upcoming = const [],
    this.results = const [],
  });

  ParticipationState copyWith({
    bool? isLoadingUpcoming,
    bool? isLoadingResults,
    String? errorUpcoming,
    String? errorResults,
    List<ParticipationModel>? upcoming,
    List<ParticipationModel>? results,
  }) {
    return ParticipationState(
      isLoadingUpcoming: isLoadingUpcoming ?? this.isLoadingUpcoming,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      errorUpcoming: errorUpcoming,
      errorResults: errorResults,
      upcoming: upcoming ?? this.upcoming,
      results: results ?? this.results,
    );
  }
}

/// --- INTENTS --- ///
abstract class ParticipationIntent {
  const ParticipationIntent();
}

/// Charger les deux listes (à venir + résultats)
class LoadParticipationIntent extends ParticipationIntent {
  const LoadParticipationIntent();
}

/// --- VIEWMODEL --- ///
class ParticipationViewModel extends ChangeNotifier {
  final TournamentRepository _repository;

  ParticipationState _state = const ParticipationState();
  ParticipationState get state => _state;

  ParticipationViewModel({TournamentRepository? repository})
      : _repository = repository ?? TournamentRepository();

  void _setState(ParticipationState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(ParticipationIntent intent) async {
    if (intent is LoadParticipationIntent) {
      await _loadParticipation();
    }
  }

  Future<void> _loadParticipation() async {
    _setState(
      _state.copyWith(
        isLoadingUpcoming: true,
        isLoadingResults: true,
        errorUpcoming: null,
        errorResults: null,
      ),
    );

    try {
      // on lance les deux en parallèle
      final upcomingFuture = fetchCalendarFromFirebase(false);
      final resultsFuture = fetchCalendarFromFirebase(true);

      final upcoming = await upcomingFuture;
      final results = await resultsFuture;

      _setState(
        _state.copyWith(
          isLoadingUpcoming: false,
          isLoadingResults: false,
          upcoming: upcoming,
          results: results,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Erreur lors du chargement de participation : $e');
        print(st);
      }
      // On met une erreur générique pour les deux listes
      _setState(
        _state.copyWith(
          isLoadingUpcoming: false,
          isLoadingResults: false,
          errorUpcoming: 'Erreur lors du chargement de mes matchs : $e',
          errorResults: 'Erreur lors du chargement de mes résultats : $e',
          upcoming: const [],
          results: const [],
        ),
      );
    }
  }

  // --- TON ANCIEN CODE LOGIQUE, inchangé ---

  Future<List<ParticipationModel>> fetchCalendarFromFirebase(bool played) async {
    final snapshot = await _repository.fetchAllSnapshot();
    if (snapshot.exists) {
      return buildListParticipation(snapshot, played);
    } else {
      if (kDebugMode) {
        print('No data available.');
      }
      return [];
    }
  }

  /// Normalise un nom pour comparaison tolérante (espaces superflus, casse).
  /// Les participants sont des noms libres tapés par le créateur du
  /// tournoi : une comparaison stricte serait trop fragile.
  String _normalizeName(String s) => s.trim().toLowerCase();

  List<ParticipationModel> buildListParticipation(
      DataSnapshot snapshot, bool played) {
    List<ParticipationModel> returnList = [];

    final Map<Object?, Object?> map =
    snapshot.value as Map<Object?, Object?>;

    // Le matching se fait sur le nom d'affichage choisi par l'utilisateur :
    // les participants sont des noms libres tapés par le créateur du
    // tournoi, pas des emails.
    final currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    if (currentUserName.isEmpty) return returnList;

    map.forEach((key, value) {
      if (value is! Map) return;
      final mapValue = value;

      final participantsRaw = mapValue['participants'];
      final participants = (participantsRaw is List) ? participantsRaw : const [];

      final bool isParticipant = participants.any(
        (p) => _normalizeName(p.toString()) == _normalizeName(currentUserName),
      );
      if (!isParticipant) return;

      // On réutilise le parsing tolérant de Tournament.fromJson (gère déjà
      // les variantes de clés 'matchList'/'matchs'/'matches' pour les
      // matchs de poule) plutôt que de dupliquer un parsing manuel fragile.
      final Tournament tournament;
      try {
        tournament = Tournament.fromJson(
          Map<String, dynamic>.from(mapValue)..['id'] = key.toString(),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Tournoi $key ignoré (parsing impossible) : $e');
        }
        return;
      }

      returnList.addAll(getMatches(tournament, currentUserName, played));
    });

    return returnList;
  }

  List<ParticipationModel> getMatches(
      Tournament tournament, String currentUserName, bool played) {
    final List<ParticipationModel> matches = [];
    final normalizedUserName = _normalizeName(currentUserName);

    void addIfInvolved(MatchTournament m) {
      // Match pas encore alimenté (phase finale pas encore générée) : ignoré.
      if (m.player1.isEmpty || m.player2.isEmpty) return;

      final bool isPlayed = m.score.isNotEmpty;
      if (isPlayed != played) return;

      final bool isPlayer1 = _normalizeName(m.player1) == normalizedUserName;
      final bool isPlayer2 = _normalizeName(m.player2) == normalizedUserName;

      if (isPlayer1 || isPlayer2) {
        final opponent = isPlayer1 ? m.player2 : m.player1;
        matches.add(
          ParticipationModel(
            date: m.date,
            location: m.location.isNotEmpty ? m.location : tournament.location,
            opposant: opponent,
            score: m.score,
          ),
        );
      }
    }

    // Phase de poules
    for (final poule in tournament.pouleList) {
      for (final m in poule.matchList) {
        addIfInvolved(m);
      }
    }

    // Phases finales
    for (final m in tournament.finalMatchList.quarterFinalList) {
      addIfInvolved(m);
    }
    for (final m in tournament.finalMatchList.semiFinalist) {
      addIfInvolved(m);
    }
    addIfInvolved(tournament.finalMatchList.finalMatch);
    addIfInvolved(tournament.finalMatchList.smallFinalMatch);

    return matches;
  }
}
