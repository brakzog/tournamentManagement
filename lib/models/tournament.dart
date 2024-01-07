import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/poule.dart';

class Tournament {
  final String name;
  final String sportEvent; //Type d'epreuve
  final TournamentDate tournamentDate;
  final String createdBy;
  final List<String> participants;
  final List<Poule> pouleList;
  EndTournament finalMatchList; //1/4, 1/2, final

  Tournament({
    required this.createdBy,
    required this.name,
    required this.sportEvent,
    required this.tournamentDate,
    required this.participants,
    required this.pouleList,
    required this.finalMatchList,
  });

  // Méthode pour convertir un objet Map en instance de Tournament.
  factory Tournament.fromMap(Map<String, dynamic> map) {
    return Tournament(
      name: map['name'],
      sportEvent: map['sportEvent'],
      createdBy: map['createdBy'],
      tournamentDate: map['tournamentDate'],
      participants: map['participants'],
      pouleList: map['pouleList'],
      finalMatchList: map['finalMatchList'],
    );
  }

  @override
  String toString() {
    return "Tournoi : $name, créé par $createdBy, pour du $sportEvent, avec ${participants.toString()} et ayant lieu ${tournamentDate.toString()}";
  }

  void updatePoule(
      String pouleToUpdate, String player1, String player2, String score) {
    Poule findPoule =
        pouleList.where((element) => element.name == pouleToUpdate).first;

    //findPoule.matchList[matchIndex].score = score;
    int index = findPoule.matchList.indexWhere((element) =>
        (element.player1 == player1 && element.player2 == player2) ||
        (element.player1 == player2 && element.player2 == player1));
    findPoule.matchList[index].score = score;
  }
}

class TournamentDate {
  String? beginingDate;
  List<String>? pouleListDate;
  List<String>? quarterListDate;
  List<String>? semiListDate;
  String? finalDate;

  TournamentDate({
    this.beginingDate,
    this.pouleListDate,
    this.quarterListDate,
    this.semiListDate,
    this.finalDate,
  });

  @override
  String toString() {
    return "begin: $beginingDate, poule: $pouleListDate, quarter: $quarterListDate, semi: $semiListDate, final: $finalDate";
  }
}


/*
Un tournoi a
 une date de tournoi,
une date max pour valider inscription
une date de début qui prend une valeur paremi les proposées
une liste de date pour les poules, 
une liste de date pour les quart de final,
une liste pour les demis et 
une date pour la finale et petite finale (<-- peut correspondre à date de fin)
*/