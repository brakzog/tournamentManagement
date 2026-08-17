import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament_date.dart';
import 'package:tournament_management/models/match.dart';


class Tournament {
  final String id;
  final String name;
  final String sportEvent;           // type d’épreuve
  final TournamentDate tournamentDate;
  final String location;
  final String createdBy;
  final List<String> participants;   // noms ou uid selon ton usage
  final List<Poule> pouleList;
  EndTournament finalMatchList;      // 1/4, 1/2, finale (mutable chez toi)
  bool isCancelled;                  // annulé par le créateur (mutable, comme finalMatchList)

  Tournament({
    required this.id,
    required this.name,
    required this.sportEvent,
    required this.tournamentDate,
    required this.location,
    required this.createdBy,
    required this.participants,
    required this.pouleList,
    required this.finalMatchList,
    this.isCancelled = false,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final rawPoules = (json['pouleList'] ?? const []) as List?;
    final rawParticipants = (json['participants'] ?? const []) as List?;

    return Tournament(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      sportEvent: (json['sportEvent'] ?? '') as String,
      tournamentDate: json['tournamentDate'] is Map<String, dynamic>
          ? TournamentDate.fromJson(json['tournamentDate'] as Map<String, dynamic>)
          : (json['tournamentDate'] is Map
              ? TournamentDate.fromJson(
                  Map<String, dynamic>.from(json['tournamentDate'] as Map))
              : const TournamentDate(start: '')),
      location: (json['location'] ?? '') as String,
      createdBy: (json['createdBy'] ?? '') as String,
      // .toList() renvoie toujours une liste "growable", même si la source
      // était const : ce repli n'est donc en pratique jamais atteint, mais
      // on le garde non-const pour ne pas induire en erreur un lecteur.
      participants: rawParticipants?.map((e) => e.toString()).toList() ?? <String>[],
      pouleList: rawPoules
              ?.map((e) => e is Map<String, dynamic>
                  ? Poule.fromJson(e)
                  : Poule.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <Poule>[],
      // Les champs de la phase finale ('finalMatch', 'smallFinalMatch',
      // 'semiFinal', 'quartFinal') sont écrits à plat à la racine du
      // tournoi dans Firebase, pas dans un objet imbriqué 'finalMatchList'.
      finalMatchList: EndTournament.fromJson(json),
      isCancelled: json['isCancelled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sportEvent': sportEvent,
        'tournamentDate': tournamentDate.toJson(),
        'location': location,
        'createdBy': createdBy,
        'participants': participants,
        'pouleList': pouleList.map((p) => p.toJson()).toList(),
        'isCancelled': isCancelled,
        // Les champs de finalMatchList sont écrits à plat, cohérent avec
        // ce que le reste de l'app écrit directement sur Firebase.
        ...finalMatchList.toJson(),
      };

  Tournament copyWith({
    String? id,
    String? name,
    String? sportEvent,
    TournamentDate? tournamentDate,
    String? location,
    String? createdBy,
    List<String>? participants,
    List<Poule>? pouleList,
    EndTournament? finalMatchList,
    bool? isCancelled,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      sportEvent: sportEvent ?? this.sportEvent,
      tournamentDate: tournamentDate ?? this.tournamentDate,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      pouleList: pouleList ?? this.pouleList,
      finalMatchList: finalMatchList ?? this.finalMatchList,
      isCancelled: isCancelled ?? this.isCancelled,
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
/// Comparaison par paire de joueurs uniquement (ordre indifférent) : la date
/// n'est pas fiable comme identifiant, elle change entre la génération du
/// match (plage de dates de la phase) et la saisie du score (date du jour).
int getIndex(List<MatchTournament> list, MatchTournament target) {
  if (list.isEmpty) return -1;
  return list.indexWhere((m) {
    if (identical(m, target)) return true; // même référence
    return (m.player1 == target.player1 && m.player2 == target.player2) ||
           (m.player1 == target.player2 && m.player2 == target.player1);
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

  final int mIndex = p.matchList.indexWhere((m) =>
      (m.player1 == player1 && m.player2 == player2) ||
      (m.player1 == player2 && m.player2 == player1));

  if (mIndex >= 0) {
    // MatchTournament.score est un champ mutable : mise à jour en place.
    p.matchList[mIndex].score = score;
  } else {
    // matchList est toujours une liste "growable" par construction (voir
    // Poule.fromJson / generatePools) : pas besoin de repli via copyWith.
    p.matchList.add(
      MatchTournament(
        player1: player1,
        player2: player2,
        score: score,
        date: '',
        location: '',
      ),
    );
  }
}
}
