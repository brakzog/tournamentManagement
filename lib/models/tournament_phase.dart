// lib/models/tournament_phase.dart
enum TournamentPhase {
  GROUP,         // phases de poules
  QUARTER_FINAL, // quarts
  SEMI_FINAL,    // demies
  SMALL_FINAL,   // petite finale (match 3e place)
  FINAL,         // finale
}
extension TournamentPhaseX on TournamentPhase {
  int get order {
    switch (this) {
      case TournamentPhase.GROUP: return 0;
      case TournamentPhase.QUARTER_FINAL: return 1;
      case TournamentPhase.SEMI_FINAL: return 2;
      case TournamentPhase.SMALL_FINAL: return 3;
      case TournamentPhase.FINAL: return 4;
    }
  }

  String get key {
    switch (this) {
      case TournamentPhase.GROUP: return 'group';
      case TournamentPhase.QUARTER_FINAL: return 'quarterFinal';
      case TournamentPhase.SEMI_FINAL: return 'semiFinal';
      case TournamentPhase.SMALL_FINAL: return 'smallFinal';
      case TournamentPhase.FINAL: return 'final';
    }
  }

  String get labelFr {
    switch (this) {
      case TournamentPhase.GROUP: return 'Poule';
      case TournamentPhase.QUARTER_FINAL: return 'Quart de finale';
      case TournamentPhase.SEMI_FINAL: return 'Demi-finale';
      case TournamentPhase.SMALL_FINAL: return 'Petite finale';
      case TournamentPhase.FINAL: return 'Finale';
    }
  }

  static TournamentPhase fromKey(String v) {
    final s = v.trim();
    switch (s) {
      case 'group':
      case 'poule':
      case 'GROUP':
        return TournamentPhase.GROUP;
      case 'quarterFinal':
      case 'quarter':
      case 'QUARTER_FINAL':
      case 'QF':
        return TournamentPhase.QUARTER_FINAL;
      case 'semiFinal':
      case 'semi':
      case 'SEMI_FINAL':
      case 'SF':
        return TournamentPhase.SEMI_FINAL;
      case 'smallFinal':
      case 'petiteFinale':
      case 'SMALL_FINAL':
        return TournamentPhase.SMALL_FINAL;
      case 'final':
      case 'FINAL':
      default:
        return TournamentPhase.FINAL;
    }
  }
}