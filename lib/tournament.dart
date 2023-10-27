class Tournament {
  final String name;
  final String sportEvent; //Type d'epreuve
  /*final List<String> wantedDates; // Liste de dates proposées
  final String dateBegun; */ // Date de commencement choisie
  final TournamentDate tournamentDate;
  final String createdBy;
  final List<String> participants;

  Tournament({
    required this.createdBy,
    required this.name,
    required this.sportEvent,
    required this.tournamentDate,
    required this.participants,
  });

  // Méthode pour convertir un objet Map en instance de Tournament.
  factory Tournament.fromMap(Map<String, dynamic> map) {
    return Tournament(
      name: map['name'],
      sportEvent: map['sportEvent'],
      createdBy: map['createdBy'],
      tournamentDate: map['tournamentDate'],
      participants: map['participants'],
    );
  }

  @override
  String toString() {
    return "Tournoi : $name, créé par $createdBy, pour du $sportEvent, avec ${participants.toString()} et ayant lieu ${tournamentDate.toString()}";
  }
}

class TournamentDate {
  final List<String> suggestionDate;
  final String expirationDate;
  String? beginingDate;
  List<String>? pouleListDate;
  List<String>? quarterListDate;
  List<String>? semiListDate;
  String? finalDate;

  TournamentDate({
    required this.suggestionDate,
    required this.expirationDate,
    this.beginingDate,
    this.pouleListDate,
    this.quarterListDate,
    this.semiListDate,
    this.finalDate,
  });

  @override
  String toString() {
    return "suggestion : $suggestionDate, expiration: $expirationDate, begin: $beginingDate, poule: $pouleListDate, quarter: $quarterListDate, semi: $semiListDate, final: $finalDate";
  }
}


/*
Un tournoi a
 une liste de date proposée,
une date max pour valider inscription
une date de début qui prend une valeur paremi les proposées
une liste de date pour les poules, 
une liste de date pour les quart de final,
une liste pour les demis et 
une date pour la finale et petite finale (<-- peut correspondre à date de fin)
*/