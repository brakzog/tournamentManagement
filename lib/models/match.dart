class MatchTournament {
  // ⚠️ Reste volontairement mutable (ton code met à jour .score in-place)
  String player1; // peut être un nom d'équipe
  String player2;
  String score;    // format conseillé : "6-4;3-6;7-5"
  String date;     // garde String pour compat avec ton code ; sinon DateTime
  String location;

  MatchTournament({
    required this.player1,
    required this.player2,
    required this.score,
    required this.date,
    required this.location,
  });

  // Lecture tolérante : accepte 'fromMap' historique et JSON standard
  factory MatchTournament.fromJson(Map<String, dynamic> json) {
    return MatchTournament(
      player1: (json['player1'] ?? '') as String,
      player2: (json['player2'] ?? '') as String,
      score: (json['score'] ?? '') as String,
      date: (json['date'] ?? '') as String,
      location: (json['location'] ?? '') as String,
    );
  }

  // Compat avec ton ancien code qui utilisait fromMap(...)
  factory MatchTournament.fromMap(Map<String, dynamic> map) =>
      MatchTournament.fromJson(map);

  Map<String, dynamic> toJson() => {
        'player1': player1,
        'player2': player2,
        'score': score,
        'date': date,
        'location': location,
      };

  MatchTournament copyWith({
    String? player1,
    String? player2,
    String? score,
    String? date,
    String? location,
  }) {
    return MatchTournament(
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      score: score ?? this.score,
      date: date ?? this.date,
      location: location ?? this.location,
    );
  }
}
