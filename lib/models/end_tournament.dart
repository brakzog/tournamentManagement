
import 'package:tournament_management/models/match.dart';

class EndTournament {
  // Reste mutable, ton code met a jour les scores in-place
  MatchTournament finalMatch;
  MatchTournament smallFinalMatch;
  List<MatchTournament> semiFinalist;
  List<MatchTournament> quarterFinalList;

  EndTournament({
    required this.finalMatch,
    required this.smallFinalMatch,
    required this.semiFinalist,
    required this.quarterFinalList,
  });

  /// Construit un [EndTournament] a partir des cles a plat telles
  /// qu'ecrites reellement dans Firebase (racine du tournoi) :
  /// 'finalMatch', 'smallFinalMatch', 'semiFinal', 'quartFinal'.
  /// Tolerant a l'absence de ces cles (tournoi dont la phase finale
  /// n'a pas encore ete generee).
  factory EndTournament.fromJson(Map<String, dynamic> json) {
    List<dynamic> asList(dynamic v) => (v as List?) ?? const [];

    MatchTournament asMatch(dynamic v) {
      if (v == null) {
        return MatchTournament(
          player1: '',
          player2: '',
          score: '',
          date: '',
          location: '',
        );
      }
      return v is Map<String, dynamic>
          ? MatchTournament.fromJson(v)
          : MatchTournament.fromJson(Map<String, dynamic>.from(v as Map));
    }

    List<MatchTournament> asMatchList(dynamic v) => asList(v)
        .map((e) => e is Map<String, dynamic>
            ? MatchTournament.fromJson(e)
            : MatchTournament.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return EndTournament(
      finalMatch: asMatch(json['finalMatch']),
      smallFinalMatch: asMatch(json['smallFinalMatch']),
      // 'semiFinal'/'quartFinal' sont les cles reellement utilisees a
      // l'ecriture ailleurs dans l'app ; on garde les anciens noms
      // camelCase en repli si jamais une autre source les utilise.
      semiFinalist: asMatchList(json['semiFinal'] ?? json['semiFinalist']),
      quarterFinalList:
          asMatchList(json['quartFinal'] ?? json['quarterFinalList']),
    );
  }

  /// Ecrit vers les memes cles a plat que celles utilisees ailleurs dans
  /// l'app pour la sauvegarde Firebase ('semiFinal'/'quartFinal').
  Map<String, dynamic> toJson() => {
        'finalMatch': finalMatch.toJson(),
        'smallFinalMatch': smallFinalMatch.toJson(),
        'semiFinal': semiFinalist.map((m) => m.toJson()).toList(),
        'quartFinal': quarterFinalList.map((m) => m.toJson()).toList(),
      };
}
