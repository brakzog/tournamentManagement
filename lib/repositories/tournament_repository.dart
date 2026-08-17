import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tournament_management/models/match.dart';

/// Point d'accès unique à Firebase pour tout ce qui touche aux tournois.
///
/// Avant ce fichier, `FirebaseDatabase.instance` était appelé directement
/// dans au moins 4 ViewModels différents (12 points d'accès distincts),
/// avec le chemin racine "tournois" recopié à chaque fois. Centraliser ici
/// permet d'injecter un faux repository dans les tests, sans avoir à
/// mocker le singleton Firebase statiquement partout.
///
/// Ce repository ne connaît que des primitives de lecture/écriture ; il ne
/// contient pas de logique métier (ex: déterminer si un match appartient
/// aux quarts ou aux demies reste la responsabilité du ViewModel, qui a
/// besoin du modèle [Tournament] pour ça).
class TournamentRepository {
  final DatabaseReference _tournoisRef;

  TournamentRepository({FirebaseDatabase? database})
      : _tournoisRef = (database ?? FirebaseDatabase.instance).ref().child('tournois');

  /// Référence racine d'un tournoi donné (tournois/{id}).
  DatabaseReference tournamentRef(String id) => _tournoisRef.child(id);

  // --- Lecture de la liste des tournois ---

  /// Flux temps réel de tous les tournois (utilisé par l'écran "Mes
  /// tournois" pour se mettre à jour automatiquement).
  Stream<DatabaseEvent> watchAll() => _tournoisRef.onValue;

  /// Lecture ponctuelle de tous les tournois (utilisée pour construire la
  /// liste "Mes participations", qui n'a pas besoin de flux temps réel).
  Future<DataSnapshot> fetchAllSnapshot() => _tournoisRef.get();

  // --- Création / suppression / annulation ---

  /// Crée un nouveau tournoi. Le champ 'id' est ajouté automatiquement à
  /// [data] avec la clé générée par Firebase.
  Future<String> createTournament(Map<String, dynamic> data) async {
    final ref = _tournoisRef.push();
    final id = ref.key!;
    await ref.set({...data, 'id': id});
    return id;
  }

  Future<void> deleteTournament(String id) async {
    await tournamentRef(id).remove();
  }

  Future<void> setCancelled(String id, bool value) async {
    await tournamentRef(id).update({'isCancelled': value});
  }

  // --- Phase de poules ---

  /// Remplace entièrement la liste des poules d'un tournoi.
  Future<void> savePools(String id, Map<String, dynamic> poulesData) async {
    final poulesRef = tournamentRef(id).child('pouleList');
    await poulesRef.remove();
    await poulesRef.set(poulesData);
  }

  /// Vérifie si un match entre ces deux joueurs a déjà un score enregistré
  /// dans la poule pointée par [pouleRef].
  Future<bool> pouleMatchExists(
      DatabaseReference pouleRef, String player1, String player2) async {
    try {
      final snapshot = (await pouleRef.child('matchs').once()).snapshot;
      if (snapshot.value == null) return false;

      final matches = snapshot.value as List<Object?>;

      for (var match in matches) {
        if (match is! Map) continue;
        final currentMatch = match;

        if (currentMatch["score"] == "") continue;

        final matchKey1 = '${currentMatch['player1']}-${currentMatch['player2']}';
        final matchKey2 = '${currentMatch['player2']}-${currentMatch['player1']}';
        final keyToCheck = '$player1-$player2';

        if (matchKey1 == keyToCheck || matchKey2 == keyToCheck) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la vérification du match: $e");
      }
      return false;
    }
  }

  /// Met à jour le score d'un match au sein d'une poule (recherche le
  /// match par paire de joueurs, ordre indifférent).
  Future<void> updatePouleMatch(
      DatabaseReference pouleRef, MatchTournament newMatch) async {
    final snapshot = await pouleRef.once();
    final value = snapshot.snapshot.value;
    if (value == null) return;

    final matches = value as Map<dynamic, dynamic>;

    for (final entry in matches.entries) {
      final matchList = entry.value;
      if (matchList is! List<Object?>) continue;

      for (int i = 0; i < matchList.length; i++) {
        final element = matchList[i];
        if (element is! Map<Object?, Object?>) continue;

        final samePlayers = (element['player1'] == newMatch.player1 &&
                element['player2'] == newMatch.player2) ||
            (element['player1'] == newMatch.player2 &&
                element['player2'] == newMatch.player1);

        if (samePlayers) {
          try {
            await pouleRef.child("matchs").child("$i").update(newMatch.toJson());
          } catch (e) {
            if (kDebugMode) {
              print("Erreur lors de la mise à jour du match $i : $e");
            }
          }
          break;
        }
      }
    }
  }

  // --- Phase finale : quarts / demies / finale / petite finale ---

  Future<void> saveQuarterFinals(String id, List<MatchTournament> matches) async {
    try {
      await tournamentRef(id).update({
        "quartFinal": matches.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement des quarts de finale : $e");
      }
    }
  }

  Future<void> saveSemiFinals(String id, List<MatchTournament> matches) async {
    try {
      await tournamentRef(id).update({
        "semiFinal": matches.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement des demi-finales : $e");
      }
    }
  }

  Future<void> saveFinalAndSmallFinal(
      String id, MatchTournament finalMatch, MatchTournament smallFinalMatch) async {
    try {
      await tournamentRef(id).update({
        "finalMatch": finalMatch.toJson(),
        "smallFinalMatch": smallFinalMatch.toJson(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement de la finale / petite finale : $e");
      }
    }
  }

  /// Remplace entièrement les tours du tableau direct (format sans
  /// poules). Réécriture complète à chaque appel : plus simple et fiable
  /// qu'un patch partiel vu que le nombre de tours change au fil du
  /// tournoi.
  Future<void> saveDirectBracketRounds(
      String id, List<List<MatchTournament>> rounds) async {
    try {
      await tournamentRef(id).update({
        "directBracketRounds": rounds
            .map((round) => round.map((m) => m.toJson()).toList())
            .toList(),
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement du tableau direct : $e");
      }
    }
  }

  /// Met à jour un match de la phase finale à l'emplacement [matchRef] déjà
  /// résolu par l'appelant (finale/petite finale : objet unique ; quarts/
  /// demies : recherche dans la liste par paire de joueurs).
  Future<void> updateBracketMatch(
      DatabaseReference matchRef, MatchTournament newMatch) async {
    final snapshot = await matchRef.once();
    final value = snapshot.snapshot.value;
    if (value == null) return;

    if (value is Map && value.containsKey('player1')) {
      // La référence pointe directement sur un match unique.
      await matchRef.update(newMatch.toJson());
      return;
    }

    if (value is Map<dynamic, dynamic>) {
      // La référence pointe sur une liste de matchs : on cherche le match
      // correspondant par joueurs.
      for (final entry in value.entries) {
        final matchData = entry.value;
        if (matchData is Map &&
            matchData['player1'] == newMatch.player1 &&
            matchData['player2'] == newMatch.player2) {
          await matchRef.child(entry.key.toString()).update(newMatch.toJson());
        }
      }
    }
  }
}
