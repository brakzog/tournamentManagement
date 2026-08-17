class TournamentDate {
  /// Dates au format "dd/MM/yyyy" (format utilise par le reste de l'app,
  /// voir create_tournament_viewmodel.dart).
  final String start; // debut du tournoi
  final String? end;  // fin (optionnel)
  final String? registrationDeadline; // date limite d'inscription (optionnel)

  const TournamentDate({
    required this.start,
    this.end,
    this.registrationDeadline,
  });

  /// Lit les cles reellement ecrites dans Firebase par
  /// create_tournament_viewmodel.dart : 'beginingDate' / 'endDate'
  /// (conserve la coquille "begining" pour rester compatible avec les
  /// donnees existantes). Les cles 'start'/'end' restent acceptees en
  /// repli au cas ou une autre source les utiliserait.
  factory TournamentDate.fromJson(Map<String, dynamic> json) => TournamentDate(
        start: (json['beginingDate'] ?? json['start'] ?? '') as String,
        end: (json['endDate'] ?? json['end']) as String?,
        registrationDeadline: json['registrationDeadline'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'beginingDate': start,
        if (end != null) 'endDate': end,
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
