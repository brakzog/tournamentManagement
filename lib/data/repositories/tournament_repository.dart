import 'package:firebase_database/firebase_database.dart';

import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/models/participation_model.dart';
import 'package:tournament_management/models/match.dart';

class TournamentRepository {
  final FirebaseDatabase _db;

  TournamentRepository({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance {
    // Cache offline (ignoré sur web) + keepSynced
    try {
      _db.setPersistenceEnabled(true);
      _db.ref('tournois').keepSynced(true);
    } catch (_) {}
  }

  DatabaseReference get _tRef => _db.ref('tournois');
  DatabaseReference _pRef(String tid) => _db.ref('participants/$tid');
  DatabaseReference _mRef(String tid) => _db.ref('matches/$tid');

  // ---------- Tournaments ----------
  Stream<List<Tournament>> watchTournaments() {
    return _tRef.onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        final map = v.cast<String, dynamic>();
        final list = map.entries.map((e) {
          final data = (e.value as Map).cast<String, dynamic>();
          return Tournament.fromJson(data);
        }).toList();
        return list;
      }
      return <Tournament>[];
    });
  }

  Future<Tournament?> getTournament(String id) async {
    final snap = await _tRef.child(id).get();
    if (!snap.exists || snap.value == null) return null;
    final data = (snap.value as Map).cast<String, dynamic>();
    return Tournament.fromJson(data);
  }

  Future<String> createTournament(Tournament t) async {
    final ref = _tRef.push();
    await ref.set(t.toJson());
    return ref.key!;
  }

  Future<void> updateTournament(String id, Tournament t) async {
    await _tRef.child(id).update(t.toJson());
  }

  Future<void> deleteTournament(String id) async {
    await Future.wait([
      _tRef.child(id).remove(),
      _pRef(id).remove(),
      _mRef(id).remove(),
    ]);
  }

  // ---------- Participants ----------
  Stream<List<ParticipationModel>> watchParticipants(String tournamentId) {
    return _pRef(tournamentId).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        final map = v.cast<String, dynamic>();
        final list = map.entries.map((e) {
          final data = (e.value as Map).cast<String, dynamic>();
          return ParticipationModel.fromJson(data);
        }).toList();
        return list;
      }
      return <ParticipationModel>[];
    });
  }

  Future<String> addParticipant(String tournamentId, ParticipationModel p) async {
    final ref = _pRef(tournamentId).push();
    await ref.set(p.toJson());
    return ref.key!;
  }

  Future<void> removeParticipant(String tournamentId, String participantKey) async {
    await _pRef(tournamentId).child(participantKey).remove();
  }

  // ---------- Matches ----------
  Stream<List<MatchTournament>> watchMatches(String tournamentId) {
    return _mRef(tournamentId).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        final map = v.cast<String, dynamic>();
        return map.entries.map((e) {
          final data = (e.value as Map).cast<String, dynamic>();
          return MatchTournament.fromJson(data);
        }).toList();
      }
      return <MatchTournament>[];
    });
  }

  Future<String> createMatch(String tournamentId, MatchTournament m) async {
    final ref = _mRef(tournamentId).push();
    await ref.set(m.toJson());
    return ref.key!;
  }

  Future<void> updateMatch(String tournamentId, String matchKey, MatchTournament m) async {
    await _mRef(tournamentId).child(matchKey).update(m.toJson());
  }

  Future<void> deleteMatch(String tournamentId, String matchKey) async {
    await _mRef(tournamentId).child(matchKey).remove();
  }
  
  // --- Lecture brute de /tournois pour réutiliser ta logique existante ---
Future<Map<Object?, Object?>> fetchAllTournamentsRaw() async {
  final snap = await _tRef.get();
  if (!snap.exists || snap.value == null) return <Object, Object>{};
  final v = snap.value;
  if (v is Map) return v as Map<Object?, Object?>;
  return <Object, Object>{};
}

// Stream d'un tournoi unique par clé Firebase
Stream<Tournament?> watchTournamentByKey(String id) {
  return _tRef.child(id).onValue.map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return null;
    final data = (event.snapshot.value as Map).cast<String, dynamic>();
    return Tournament.fromJson(data);
  });
}


/// Stream live de la liste des participants
  Stream<List<String>> watchParticipantsList(String tournamentId) {
    return _tRef.child(tournamentId).child('participants').onValue.map((e) {
      final v = e.snapshot.value;

      if (v is List) {
        // Liste "pure"
        return v.map((e) => e.toString()).toList();
      }
      if (v is Map) {
        // Firebase peut trouer une liste -> Map indexée {"0": "..."}
        return (v as Map).values.map((e) => e.toString()).toList();
      }
      return <String>[];
    });
  }

  /// Ajout (dé-doublonné) d'un participant
  Future<void> addParticipantToTournament(String tournamentId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _tRef.child(tournamentId).child('participants').runTransaction((current) {
      final List<String> list = () {
        if (current is List) {
          return current.map((e) => e.toString()).toList();
        } else if (current is Map) {
          return (current as Map).values.map((e) => e.toString()).toList();
        }
        return <String>[];
      }();

      if (!list.contains(trimmed)) list.add(trimmed);
      return Transaction.success(list);
    });
  }

  /// Suppression d'un participant
  Future<void> removeParticipantFromTournament(String tournamentId, String name) async {
    await _tRef.child(tournamentId).child('participants').runTransaction((current) {
      final List<String> list = () {
        if (current is List) {
          return current.map((e) => e.toString()).toList();
        } else if (current is Map) {
          return (current as Map).values.map((e) => e.toString()).toList();
        }
        return <String>[];
      }();

      list.removeWhere((e) => e == name);
      return Transaction.success(list);
    });
  }
  
  
Future<void> updatePouleMatchScore(
  String tournamentId,
  String pouleName,
  int matchIndex, {
  String? score,
  String? player1,
  String? player2,
  String? date,
  String? location,
}) async {
  final updates = <String, Object?>{};
  if (score != null) updates['score'] = score;
  if (player1 != null) updates['player1'] = player1;
  if (player2 != null) updates['player2'] = player2;
  if (date != null) updates['date'] = date;
  if (location != null) updates['location'] = location;

  if (updates.isEmpty) return;

  // /tournois/{id}/pouleList/{pouleName}/matchs/{index}/...
  await _tRef
      .child(tournamentId)
      .child('pouleList')
      .child(pouleName)
      .child('matchs')
      .child(matchIndex.toString())
      .update(updates);
}


Future<void> updateQuarterFinalMatchScore(
  String tournamentId,
  int index, {
  String? score,
  String? player1,
  String? player2,
  String? date,
  String? location,
}) async {
  final updates = <String, Object?>{};
  if (score != null) updates['score'] = score;
  if (player1 != null) updates['player1'] = player1;
  if (player2 != null) updates['player2'] = player2;
  if (date != null) updates['date'] = date;
  if (location != null) updates['location'] = location;

  if (updates.isEmpty) return;
  await _tRef
      .child(tournamentId)
      .child('quartFinal')
      .child(index.toString())
      .update(updates);
}

Future<void> updateSemiFinalMatchScore(
  String tournamentId,
  int index, {
  String? score,
  String? player1,
  String? player2,
  String? date,
  String? location,
}) async {
  final updates = <String, Object?>{};
  if (score != null) updates['score'] = score;
  if (player1 != null) updates['player1'] = player1;
  if (player2 != null) updates['player2'] = player2;
  if (date != null) updates['date'] = date;
  if (location != null) updates['location'] = location;

  if (updates.isEmpty) return;
  await _tRef
      .child(tournamentId)
      .child('semiFinal')
      .child(index.toString())
      .update(updates);
}

Future<void> updateFinalOrSmallFinalScore(
  String tournamentId, {
  required bool smallFinal, // false = finale, true = petite finale
  String? score,
  String? player1,
  String? player2,
  String? date,
  String? location,
}) async {
  final updates = <String, Object?>{};
  if (score != null) updates['score'] = score;
  if (player1 != null) updates['player1'] = player1;
  if (player2 != null) updates['player2'] = player2;
  if (date != null) updates['date'] = date;
  if (location != null) updates['location'] = location;

  if (updates.isEmpty) return;
  final node = smallFinal ? 'smallFinal' : 'finalMatch';
  await _tRef.child(tournamentId).child(node).update(updates);
}


}
