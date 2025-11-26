class TournamentDate {
  final String start;
  final String? end;

  const TournamentDate({ required this.start, this.end });

  factory TournamentDate.fromJson(Map<String, dynamic> json) {
    final s = (json['beginingDate'] ?? json['start'] ?? '') as String;
    final e = (json['endDate'] ?? json['end']) as String?;
    return TournamentDate(start: s, end: e);
  }

  Map<String, dynamic> toJson() => {
    // On �crit avec les m�mes cl�s que ton code historique
    'beginingDate': start,
    if (end != null && end!.isNotEmpty) 'endDate': end,
  };

  TournamentDate copyWith({ String? start, String? end }) =>
      TournamentDate(start: start ?? this.start, end: end ?? this.end);
}
