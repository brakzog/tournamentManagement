class MatchTournament {
  String player1; // can also be a name for team player
  String player2;
  String score;
  String date;
  String location;

  MatchTournament({
    required this.player1,
    required this.player2,
    required this.score,
    required this.date,
    required this.location,
  });

  factory MatchTournament.fromMap(Map<String, dynamic> map) {
    return MatchTournament(
      player1: map['player1'],
      player2: map['player2'],
      score: map['score'],
      date: map['date'],
      location: map['location']
    );
  }

// Méthode toJson dans la classe Match
  Map<String, dynamic> toJson() {
    return {
      'player1': player1,
      'player2': player2,
      'score': score,
      'date': date,
      'location': location,
    };
  }
}
