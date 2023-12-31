import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';

String getWinner(MatchTournament match) {
  if (match.score == "") {
    return "";
  }
  // Diviser la chaîne de score en une liste de sets
  List<String> sets = match.score.split(';');

  int player1Wins = 0;
  int player2Wins = 0;

  // Parcourir chaque set et compter les victoires pour chaque joueur
  for (String set in sets) {
    List<String> scores = set.split('-');
    int player1Score = int.parse(scores[0]);
    int player2Score = int.parse(scores[1]);

    if (player1Score > player2Score) {
      player1Wins++;
    } else if (player2Score > player1Score) {
      player2Wins++;
    }
  }

  // Déterminer le joueur gagnant en comparant le nombre total de victoires
  if (player1Wins > player2Wins) {
    return match.player1;
  } else {
    return match.player2;
  }
}

List<String> calculateRanking(Poule poule) {
  // Initialiser un map pour stocker le nombre de victoires de chaque joueur
  Map<String, int> victories = {};

  // Parcourir la liste des matchs de la poule
  for (MatchTournament match in poule.matchList) {
    // Découper le score pour obtenir les différents sets
    List<String> sets = match.score.split(';');

    // Compter le nombre de sets gagnés par chaque joueur
    int victoriesPlayer1 = 0;
    int victoriesPlayer2 = 0;

    for (String set in sets) {
      List<String> scores = set.split('-');
      if (scores.length == 2) {
        if (int.parse(scores[0]) > int.parse(scores[1])) {
          victoriesPlayer1++;
        } else if (int.parse(scores[1]) > int.parse(scores[0])) {
          victoriesPlayer2++;
        }
      }
    }

    // Déterminer le gagnant du match
    String winner = victoriesPlayer1 > victoriesPlayer2
        ? match.player1
        : victoriesPlayer2 > victoriesPlayer1
            ? match.player2
            : ''; // Si égalité, pas de gagnant

    // Mettre à jour le nombre total de victoires pour chaque joueur
    victories[match.player1] = (victories[match.player1] ?? 0) +
        (winner == match.player1
            ? 1
            : 0); // Incrémenter si le joueur est le gagnant
    victories[match.player2] = (victories[match.player2] ?? 0) +
        (winner == match.player2
            ? 1
            : 0); // Incrémenter si le joueur est le gagnant
  }

  // Convertir le map en une liste triée par victoires décroissantes
  List<MapEntry<String, int>> sortedEntries = victories.entries.toList()
    ..sort((entry1, entry2) => entry2.value.compareTo(entry1.value));

  // Construire la liste de classement sous forme de chaînes de texte
  List<String> ranking = sortedEntries
      .asMap()
      .map((index, entry) =>
          MapEntry(index + 1, "${entry.key} - ${entry.value} victoires"))
      .values
      .toList();

  return ranking;
}
