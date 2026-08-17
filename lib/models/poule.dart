import 'package:tournament_management/models/match.dart';

class Poule {
  final String name; // "Poule A", "Poule B", etc.
  final List<MatchTournament> matchList;
  final List<String> playerList;

  const Poule({
    required this.name,
    required this.matchList,
    required this.playerList,
  });

  /// Lecture tolérante :
  /// - joueurs : "playerList" OU "players"
  /// - matchs  : "matchList"  OU "matchs" / "matches"
  factory Poule.fromJson(Map<String, dynamic> json) {
    final rawPlayers =
        (json['playerList'] ?? json['players'] ?? const []) as List?;
    final rawMatches =
        (json['matchList'] ?? json['matchs'] ?? json['matches'] ?? const []) as List?;

    return Poule(
      name: (json['name'] ?? '') as String,
      // .toList() renvoie toujours une liste "growable", même si la source
      // était const : ces valeurs de repli ne sont donc en pratique jamais
      // atteintes, mais on les garde non-const pour ne pas induire en
      // erreur un lecteur qui penserait matchList/playerList immuables.
      playerList: rawPlayers?.map((e) => e.toString()).toList() ?? <String>[],
      matchList: rawMatches
              ?.map((e) => e is Map<String, dynamic>
                  ? MatchTournament.fromJson(e)
                  : MatchTournament.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <MatchTournament>[],
    );
  }

  // Compat avec ton ancien code qui utilisait fromMap(...)
  factory Poule.fromMap(Map<String, dynamic> map) => Poule.fromJson(map);

  /// Clé canonique en écriture :
  /// - "playerList" pour les joueurs
  /// - "matchList" pour les matchs
  Map<String, dynamic> toJson() => {
        'name': name,
        'playerList': playerList,
        'matchList': matchList.map((m) => m.toJson()).toList(),
      };

  Poule copyWith({
    String? name,
    List<MatchTournament>? matchList,
    List<String>? playerList,
  }) {
    return Poule(
      name: name ?? this.name,
      matchList: matchList ?? this.matchList,
      playerList: playerList ?? this.playerList,
    );
  }
}
