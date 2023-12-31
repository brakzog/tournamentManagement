import 'package:tournament_management/models/match.dart';

class Poule {
  final String name; // poule A, B ...
  final List<MatchTournament> matchList;
  final List<String> playerList;

  Poule({
    required this.name,
    required this.matchList,
    required this.playerList,
  });

  // Méthode pour convertir un objet Map en instance de Tournament.
  factory Poule.fromMap(Map<String, dynamic> map) {
    return Poule(
      name: map['name'],
      matchList: map["matchList"],
      playerList: map['playerList'],
    );
  }

  // Ajoutez cette méthode à votre classe Poule pour convertir une poule en map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'players': playerList.map((player) => player).toList(),
      'matchs': matchList.map((match) => match.toJson()).toList(),
    };
  }
}
