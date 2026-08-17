/// Format de déroulement du tournoi, choisi à la création.
enum BracketFormat {
  /// Poules qualificatives, puis quarts / demies / finale (comportement
  /// historique de l'app).
  poules,

  /// Tableau à élimination directe dès le premier tour, sans phase de
  /// poules. La taille du tableau est calculée automatiquement à partir
  /// du nombre de participants.
  directBracket,
}

extension BracketFormatX on BracketFormat {
  String get key {
    switch (this) {
      case BracketFormat.poules:
        return 'poules';
      case BracketFormat.directBracket:
        return 'directBracket';
    }
  }

  static BracketFormat fromKey(String? v) {
    switch (v) {
      case 'directBracket':
        return BracketFormat.directBracket;
      case 'poules':
      default:
        return BracketFormat.poules;
    }
  }
}
