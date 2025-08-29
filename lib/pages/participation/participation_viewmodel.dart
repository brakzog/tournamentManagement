import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:tournament_management/models/participation_model.dart';
import 'package:tournament_management/data/repositories/tournament_repository.dart';

class ParticipationViewModel extends ChangeNotifier {
  final TournamentRepository _repo;
  ParticipationViewModel(this._repo);


  Future<List<ParticipationModel>> fetchCalendarFromFirebase(bool played) async {
    // On passe par le repo (plus d'accès direct au DB ici)
    final raw = await _repo.fetchAllTournamentsRaw();
    if (raw.isEmpty) {
      if (kDebugMode) print('No data available.');
      return <ParticipationModel>[];
    }
    return buildListParticipationFromMap(raw, played);
  }

  // (Compat facultative) Si ailleurs tu appelles encore cette signature :
  Future<List<ParticipationModel>> buildListParticipation(
      DataSnapshot snapshot, bool played) async {
    if (!snapshot.exists || snapshot.value == null) return <ParticipationModel>[];
    final root = snapshot.value;
    if (root is! Map) return <ParticipationModel>[];
    return buildListParticipationFromMap(root as Map<Object?, Object?>, played);
  }

  // --- Nouvelle impl interne : même logique que la tienne, mais robuste ---
  Future<List<ParticipationModel>> buildListParticipationFromMap(
      Map<Object?, Object?> map, bool played) async {
    final List<ParticipationModel> returnList = [];

    final currentUser = FirebaseAuth.instance.currentUser?.email;
    if (currentUser == null || currentUser.isEmpty) {
      if (kDebugMode) print('No current user.');
      return returnList;
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final tournamentData = value as Map<Object?, Object?>;

      final participants = _asStringList(tournamentData["participants"]);
      if (!participants.contains(currentUser)) continue;

      final matches = getMatches(tournamentData, currentUser, played);
      returnList.addAll(matches);
    }

    return returnList;
  }

  List<ParticipationModel> getMatches(
      Map<Object?, Object?> tournamentData, String userEmail, bool played) {
    final List<ParticipationModel> out = [];

    // -------- Phases finales --------
    // Variantes possibles selon ta DB : finalMatch / smallFinalMatch / semiFinal / quartFinal / quarterFinalList
    out.addAll(_extractRound(tournamentData['finalMatch'], userEmail, played));
    out.addAll(_extractRound(tournamentData['smallFinalMatch'], userEmail, played));

    final semi = tournamentData['semiFinal'];
    out.addAll(_extractRound(semi, userEmail, played));

    final quart = tournamentData['quartFinal'] ?? tournamentData['quarterFinalList'];
    out.addAll(_extractRound(quart, userEmail, played));

    // -------- Poules --------
    // pouleList peut être Map {A: {...}} ou List [{...}]
    final pouleRaw = tournamentData['pouleList'];
    if (pouleRaw is Map) {
      for (final p in pouleRaw.values) {
        if (p is Map) {
          final matchs = p['matchs'] ?? p['matchList'];
          out.addAll(_extractRound(matchs, userEmail, played));
        }
      }
    } else if (pouleRaw is List) {
      for (final p in pouleRaw) {
        if (p is Map) {
          final matchs = p['matchs'] ?? p['matchList'];
          out.addAll(_extractRound(matchs, userEmail, played));
        }
      }
    }

    return out;
  }

  // ----- Helpers -----

  List<ParticipationModel> _extractRound(
      dynamic round, String userEmail, bool played) {
    final List<ParticipationModel> res = [];
    if (round == null) return res;

    // 1 match (Map)
    if (round is Map && _looksLikeMatch(round)) {
      final m = _toParticipation(round, userEmail, played);
      if (m != null) res.add(m);
      return res;
    }

    // Liste de matches
    if (round is List) {
      for (final item in round) {
        if (item is Map && _looksLikeMatch(item)) {
          final m = _toParticipation(item, userEmail, played);
          if (m != null) res.add(m);
        }
      }
      return res;
    }

    // Map indexée { "0": {...}, "1": {...} }
    if (round is Map) {
      for (final v in round.values) {
        if (v is Map && _looksLikeMatch(v)) {
          final m = _toParticipation(v, userEmail, played);
          if (m != null) res.add(m);
        }
      }
      return res;
    }

    return res;
  }

  bool _looksLikeMatch(Map m) =>
      m.containsKey('player1') && m.containsKey('player2') && m.containsKey('score');

  ParticipationModel? _toParticipation(Map m, String userEmail, bool played) {
    final p1 = m['player1']?.toString() ?? '';
    final p2 = m['player2']?.toString() ?? '';
    final score = (m['score'] ?? '').toString();

    // ⚠️ Parenthèses indispensables
    final involvement = (p1 == userEmail) || (p2 == userEmail);
    final okPlayed = played ? score.isNotEmpty : score.isEmpty;

    if (!involvement || !okPlayed) return null;

    final date = m['date']?.toString() ?? '';
    final location = m['location']?.toString() ?? '';
    final opposant = (p1 == userEmail) ? p2 : p1;

    return ParticipationModel(
      date: date,
      location: location,
      opposant: opposant,
      score: score,
    );
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is Map) return v.values.map((e) => e.toString()).toList();
    return <String>[];
  }
}
