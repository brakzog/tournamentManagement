import 'package:tournament_management/models/match.dart';

class EndTournament {
  MatchTournament finalMatch;
  MatchTournament smallFinalMatch;
  List<MatchTournament> semiFinalist;
  List<MatchTournament> quarterFinalList;

  EndTournament(
      {required this.finalMatch,
      required this.smallFinalMatch,
      required this.semiFinalist,
      required this.quarterFinalList});
}
