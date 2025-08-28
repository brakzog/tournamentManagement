class ParticipationModel {
  final String date;      // ex. "2025-08-28" ou "dd/MM/yyyy"
  final String location;
  final String opposant;
  final String score;

  const ParticipationModel({
    required this.date,
    required this.location,
    required this.opposant,
    required this.score,
  });

  factory ParticipationModel.fromJson(Map<String, dynamic> json) {
    return ParticipationModel(
      date: (json['date'] ?? '') as String,
      location: (json['location'] ?? '') as String,
      opposant: (json['opposant'] ?? '') as String,
      score: (json['score'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'location': location,
        'opposant': opposant,
        'score': score,
      };

  ParticipationModel copyWith({
    String? date,
    String? location,
    String? opposant,
    String? score,
  }) {
    return ParticipationModel(
      date: date ?? this.date,
      location: location ?? this.location,
      opposant: opposant ?? this.opposant,
      score: score ?? this.score,
    );
  }
}
