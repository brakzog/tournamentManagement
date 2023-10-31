class MatchTournament {
  final String player1; // can also be a name for team player
  final String player2;
  String score;

  MatchTournament({
    required this.player1,
    required this.player2,
    required this.score,
  });

  factory MatchTournament.fromMap(Map<String, dynamic> map) {
    return MatchTournament(
      player1: map['player1'],
      player2: map['player2'],
      score: map['score'],
    );
  }
}
