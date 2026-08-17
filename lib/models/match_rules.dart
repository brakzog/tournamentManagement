/// Règles de victoire d'un match : combien de points pour gagner un set,
/// si un écart de 2 points est requis, et combien de sets gagnants sont
/// nécessaires pour remporter le match.
class MatchRules {
  final int pointsPerSet;
  final bool winByTwo;
  final int setsToWin;

  const MatchRules({
    required this.pointsPerSet,
    required this.winByTwo,
    required this.setsToWin,
  });

  /// Règles par défaut : utilisées si rien n'est configuré, notamment pour
  /// les tournois créés avant l'ajout de cette fonctionnalité.
  static const MatchRules fallback = MatchRules(
    pointsPerSet: 6,
    winByTwo: true,
    setsToWin: 1,
  );

  factory MatchRules.fromJson(Map<String, dynamic> json) {
    return MatchRules(
      pointsPerSet: _asInt(json['pointsPerSet']) ?? fallback.pointsPerSet,
      winByTwo:
      json['winByTwo'] is bool ? json['winByTwo'] as bool : fallback.winByTwo,
      setsToWin: _asInt(json['setsToWin']) ?? fallback.setsToWin,
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
    'pointsPerSet': pointsPerSet,
    'winByTwo': winByTwo,
    'setsToWin': setsToWin,
  };

  MatchRules copyWith({
    int? pointsPerSet,
    bool? winByTwo,
    int? setsToWin,
  }) {
    return MatchRules(
      pointsPerSet: pointsPerSet ?? this.pointsPerSet,
      winByTwo: winByTwo ?? this.winByTwo,
      setsToWin: setsToWin ?? this.setsToWin,
    );
  }

  @override
  String toString() =>
      'MatchRules(pointsPerSet: $pointsPerSet, winByTwo: $winByTwo, setsToWin: $setsToWin)';
}
