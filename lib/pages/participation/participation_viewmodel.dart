import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tournament_management/models/participation_model.dart';

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
  ParticipationState _state = const ParticipationState();
  ParticipationState get state => _state;

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
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child('tournois').get();
    if (snapshot.exists) {
      return buildListParticipation(snapshot, played);
    } else {
      if (kDebugMode) {
        print('No data available.');
      }
      return [];
    }
  }

  List<ParticipationModel> buildListParticipation(
      DataSnapshot snapshot, bool played) {
    List<ParticipationModel> returnList = [];

    final Map<Object?, Object?> map =
    snapshot.value as Map<Object?, Object?>;

    final userEmail = FirebaseAuth.instance.currentUser?.email;

    map.forEach((key, value) {
      final mapValue = value as Map<Object?, Object?>;

      final location = mapValue['location'] as String?;
      final participants = mapValue['participants'] as List<Object?>;

      if (participants.contains(userEmail)) {
        // on récupère les matchs pertinents pour ce tournoi
        returnList.addAll(
          getMatches(mapValue, userEmail ?? '', played).map(
                (m) => ParticipationModel(
              location: location ?? '',
              date: m.date,
              opposant: m.opposant,
              score: m.score,
            ),
          ),
        );
      }
    });

    return returnList;
  }

  List<ParticipationModel> getMatches(
      Map<Object?, Object?> tournamentData, String userEmail, bool played) {
    // Ton implémentation actuelle ici (copiée depuis ton fichier d’origine)
    // Je laisse intacte ta logique interne, on ne touche pas aux détails
    // de filtre par phase / score / etc.

    List<ParticipationModel> matches = [];

    // ... ici tu gardes le contenu exact que tu avais déjà ...
    // (parcours des poules + phases finales et création de ParticipationModel)

    return matches;
  }
}
