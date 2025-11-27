class TournamentDate {
  /// Dates au format ISO "yyyy-MM-dd" ou "dd/MM/yyyy" selon ton UI actuelle.
  /// Si tu pr?f?res, remplace par des DateTime et formate ? l?affichage.
  final String start; // d?but du tournoi
  final String? end;  // fin (optionnel)
  final String? registrationDeadline; // date limite d'inscription (optionnel)

  const TournamentDate({
    required this.start,
    this.end,
    this.registrationDeadline,
  });

  factory TournamentDate.fromJson(Map<String, dynamic> json) => TournamentDate(
        start: (json['start'] ?? '') as String,
        end: json['end'] as String?,
        registrationDeadline: json['registrationDeadline'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        if (end != null) 'end': end,
        if (registrationDeadline != null)
          'registrationDeadline': registrationDeadline,
      };

  TournamentDate copyWith({
    String? start,
    String? end,
    String? registrationDeadline,
  }) {
    return TournamentDate(
      start: start ?? this.start,
      end: end ?? this.end,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
    );
    }
}
