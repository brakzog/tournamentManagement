import 'package:tournament_management/models/match_rules.dart';
import 'package:tournament_management/models/tournament_phase.dart';

/// Règles de match applicables à un tournoi, avec une éventuelle
/// dérogation pour la phase finale (demi-finales, finale, petite finale) —
/// par exemple exiger plus de sets gagnants qu'aux tours précédents.
class TournamentRules {
  final MatchRules defaultRules;
  final MatchRules? finalPhaseRules;

  const TournamentRules({
    required this.defaultRules,
    this.finalPhaseRules,
  });

  static const TournamentRules fallback = TournamentRules(
    defaultRules: MatchRules.fallback,
  );

  /// Règles applicables pour une phase donnée : demies/finale/petite
  /// finale utilisent [finalPhaseRules] si défini, sinon [defaultRules].
  MatchRules rulesFor(TournamentPhase phase) {
    final isFinalPhase = phase == TournamentPhase.SEMI_FINAL ||
        phase == TournamentPhase.FINAL ||
        phase == TournamentPhase.SMALL_FINAL;
    if (isFinalPhase && finalPhaseRules != null) {
      return finalPhaseRules!;
    }
    return defaultRules;
  }

  factory TournamentRules.fromJson(Map<String, dynamic> json) {
    final rawDefault = json['defaultRules'];
    final rawFinal = json['finalPhaseRules'];

    return TournamentRules(
      defaultRules: rawDefault is Map
          ? MatchRules.fromJson(Map<String, dynamic>.from(rawDefault))
          : MatchRules.fallback,
      finalPhaseRules: rawFinal is Map
          ? MatchRules.fromJson(Map<String, dynamic>.from(rawFinal))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultRules': defaultRules.toJson(),
    if (finalPhaseRules != null) 'finalPhaseRules': finalPhaseRules!.toJson(),
  };

  TournamentRules copyWith({
    MatchRules? defaultRules,
    MatchRules? finalPhaseRules,
    bool clearFinalPhaseRules = false,
  }) {
    return TournamentRules(
      defaultRules: defaultRules ?? this.defaultRules,
      finalPhaseRules:
      clearFinalPhaseRules ? null : (finalPhaseRules ?? this.finalPhaseRules),
    );
  }
}
