
import 'package:tournament_management/models/match.dart';

class EndTournament {
  // Reste mutable, ton code met à jour les scores in-place
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

  factory EndTournament.fromJson(Map<String, dynamic> json) {
    List<dynamic> _list(dynamic v) => (v as List?) ?? const [];

    return EndTournament(
      finalMatch: json['finalMatch'] is Map<String, dynamic>
          ? MatchTournament.fromJson(json['finalMatch'] as Map<String, dynamic>)
          : MatchTournament.fromJson(
              Map<String, dynamic>.from(json['finalMatch'] as Map)),
      smallFinalMatch: json['smallFinalMatch'] is Map<String, dynamic>
          ? MatchTournament.fromJson(json['smallFinalMatch'] as Map<String, dynamic>)
          : MatchTournament.fromJson(
              Map<String, dynamic>.from(json['smallFinalMatch'] as Map)),
      semiFinalist: _list(json['semiFinalist'])
          .map((e) => e is Map<String, dynamic>
              ? MatchTournament.fromJson(e)
              : MatchTournament.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      quarterFinalList: _list(json['quarterFinalList'])
          .map((e) => e is Map<String, dynamic>
              ? MatchTournament.fromJson(e)
              : MatchTournament.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'finalMatch': finalMatch.toJson(),
        'smallFinalMatch': smallFinalMatch.toJson(),
        'semiFinalist': semiFinalist.map((m) => m.toJson()).toList(),
        'quarterFinalList': quarterFinalList.map((m) => m.toJson()).toList(),
      };
}
