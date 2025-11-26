import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament_date.dart';
import 'package:tournament_management/models/match.dart';

import 'end_tournament.dart';


class Tournament {
  // ⚠️ Ton code d’origine (vu dans tes ViewModels) ne stocke pas d'ID ici.
  // L’ID Firebase est la clé du nœud. On garde ce choix pour éviter de casser.
  final String name;
  final String sportEvent;           // type d’épreuve
  final TournamentDate tournamentDate;
  final String location;
  final String createdBy;
  final List<String> participants;   // noms ou uid selon ton usage
  final List<Poule> pouleList;
  EndTournament finalMatchList;      // 1/4, 1/2, finale (mutable chez toi)

  Tournament({
    required this.name,
    required this.sportEvent,
    required this.tournamentDate,
    required this.location,
    required this.createdBy,
    required this.participants,
    required this.pouleList,
    required this.finalMatchList,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final rawPoules = (json['pouleList'] ?? const []) as List?;
    final rawParticipants = (json['participants'] ?? const []) as List?;

    return Tournament(
      name: (json['name'] ?? '') as String,
      sportEvent: (json['sportEvent'] ?? '') as String,
      tournamentDate: json['tournamentDate'] is Map<String, dynamic>
          ? TournamentDate.fromJson(json['tournamentDate'] as Map<String, dynamic>)
          : TournamentDate.fromJson(
              Map<String, dynamic>.from(json['tournamentDate'] as Map)),
      location: (json['location'] ?? '') as String,
      createdBy: (json['createdBy'] ?? '') as String,
      participants: rawParticipants?.map((e) => e.toString()).toList() ?? const <String>[],
      pouleList: rawPoules
              ?.map((e) => e is Map<String, dynamic>
                  ? Poule.fromJson(e)
                  : Poule.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <Poule>[],
      finalMatchList: json['finalMatchList'] is Map<String, dynamic>
          ? EndTournament.fromJson(json['finalMatchList'] as Map<String, dynamic>)
          : EndTournament.fromJson(
              Map<String, dynamic>.from(json['finalMatchList'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sportEvent': sportEvent,
        'tournamentDate': tournamentDate.toJson(),
        'location': location,
        'createdBy': createdBy,
        'participants': participants,
        'pouleList': pouleList.map((p) => p.toJson()).toList(),
        'finalMatchList': finalMatchList.toJson(),
      };

  Tournament copyWith({
    String? name,
    String? sportEvent,
    TournamentDate? tournamentDate,
    String? location,
    String? createdBy,
    List<String>? participants,
    List<Poule>? pouleList,
    EndTournament? finalMatchList,
  }) {
    return Tournament(
      name: name ?? this.name,
      sportEvent: sportEvent ?? this.sportEvent,
      tournamentDate: tournamentDate ?? this.tournamentDate,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      pouleList: pouleList ?? this.pouleList,
      finalMatchList: finalMatchList ?? this.finalMatchList,
    );
  }
  
  /// Met à jour la FINALE (remplace le match de finale).
void updateFinaleMatch(MatchTournament newMatch) {
  // Si EndTournament est mutable (comme dans nos modèles), on remplace in-place :
  finalMatchList.finalMatch = newMatch;
}

/// Alias défensif si ton presenter utilise un autre nom
void updateFinalMatch(MatchTournament newMatch) => updateFinaleMatch(newMatch);

/// Met à jour la PETITE FINALE (match pour la 3e place).
void updateSmallFinaleMatch(MatchTournament newMatch) {
  finalMatchList.smallFinalMatch = newMatch;
}

/// Alias défensif (si code historique “petite” en FR) :
void updatePetiteFinaleMatch(MatchTournament newMatch) => updateSmallFinaleMatch(newMatch);

/// Met à jour/insère un match de DEMI-FINALE (on identifie par joueurs/date/lieu, score ignoré pour l’ID logique).
void upsertSemiFinalMatch(MatchTournament newMatch) {
  final list = finalMatchList.semiFinalist;
  final idx = getIndex(list, newMatch);
  if (idx >= 0) {
    // remplace l’élément (plus robuste que muter score seulement)
    list[idx] = newMatch;
  } else {
    list.add(newMatch);
  }
}

/// Met à jour/insère un match de QUART-DE-FINALE.
void upsertQuarterFinalMatch(MatchTournament newMatch) {
  final list = finalMatchList.quarterFinalList;
  final idx = getIndex(list, newMatch);
  if (idx >= 0) {
    list[idx] = newMatch;
  } else {
    list.add(newMatch);
  }
}

/// Utilitaire : retrouve l’index d’un match dans une liste (identité logique).
int getIndex(List<MatchTournament> list, MatchTournament target) {
  if (list.isEmpty) return -1;
  return list.indexWhere((m) {
    if (identical(m, target)) return true; // même référence
    // égalité logique : on ignore le score (souvent modifié après-coup)
    return m.player1 == target.player1 &&
           m.player2 == target.player2 &&
           m.date == target.date &&
           m.location == target.location;
  });
}

void updatePoule(Object selectedPoule, String player1, String player2, String score) {
  String pouleName;
  if (selectedPoule is String) {
    pouleName = selectedPoule;
  } else if (selectedPoule is Poule) {
    pouleName = selectedPoule.name;
  } else {
    pouleName = selectedPoule.toString();
  }

  final int pIndex = pouleList.indexWhere((p) => p.name == pouleName);
  if (pIndex < 0) return;

  final Poule p = pouleList[pIndex];

  int mIndex = p.matchList.indexWhere((m) =>
      (m.player1 == player1 && m.player2 == player2) ||
      (m.player1 == player2 && m.player2 == player1));

  if (mIndex >= 0) {
    try {
      p.matchList[mIndex].score = score;
    } catch (_) {
      final updatedMatches = List<MatchTournament>.from(p.matchList);
      updatedMatches[mIndex] = updatedMatches[mIndex].copyWith(score: score);
      pouleList[pIndex] = p.copyWith(matchList: updatedMatches);
    }
  } else {
    final newMatch = MatchTournament(
      player1: player1,
      player2: player2,
      score: score,
      date: '',
      location: '',
    );
    try {
      p.matchList.add(newMatch);
    } catch (_) {
      final updatedMatches = <MatchTournament>[...p.matchList, newMatch];
      pouleList[pIndex] = p.copyWith(matchList: updatedMatches);
    }
  }
}

}
