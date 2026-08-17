import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/match_rules.dart';
import 'package:tournament_management/models/poule.dart';

/// Calcule la taille de tableau (puissance de 2) immédiatement supérieure
/// ou égale à [n]. Ex: 13 -> 16, 8 -> 8, 5 -> 8.
int nextPowerOfTwo(int n) {
  if (n < 1) return 1;
  int power = 1;
  while (power < n) {
    power *= 2;
  }
  return power;
}

/// Plan du premier tour d'un tableau à élimination directe (sans poules).
///
/// - Sans repêchage : le tableau est directement dimensionné à la
///   puissance de 2 supérieure au nombre de participants ; l'écart donne
///   les exempts ("byes") du 1er tour, qualifiés d'office pour le 2e tour.
/// - Avec repêchage : tous les participants jouent le 1er tour (parité
///   gérée par un bye si nombre impair, inévitable mathématiquement) ; le
///   2e tour est dimensionné à la puissance de 2 supérieure au nombre de
///   qualifiés naturels (vainqueurs + bye éventuel), et le repêchage
///   comble exactement l'écart restant — aucun bye supplémentaire.
class FirstRoundPlan {
  final int totalParticipants;

  /// Nombre de participants qui jouent réellement le 1er tour.
  final int firstRoundPlayers;

  /// Nombre de matchs joués au 1er tour.
  final int firstRoundMatches;

  /// Exempts directs du 1er tour (qualifiés sans jouer). Sans repêchage,
  /// peut être > 1 (écart à la puissance de 2). Avec repêchage, vaut 0 ou
  /// 1 uniquement (parité).
  final int firstRoundByes;

  /// Taille du 2e tour (nombre de qualifiés qui s'affronteront ensuite).
  final int nextRoundSize;

  /// Nombre de repêchés nécessaires pour compléter le 2e tour (0 si le
  /// tournoi ne repêche pas, ou si aucun repêché n'est nécessaire).
  final int repechageNeeded;

  const FirstRoundPlan({
    required this.totalParticipants,
    required this.firstRoundPlayers,
    required this.firstRoundMatches,
    required this.firstRoundByes,
    required this.nextRoundSize,
    required this.repechageNeeded,
  });
}

/// Calcule le [FirstRoundPlan] pour [totalParticipants] participants,
/// selon que le tournoi utilise ou non le repêchage.
FirstRoundPlan computeFirstRoundPlan(
    int totalParticipants, {
      required bool useRepechage,
    }) {
  if (totalParticipants < 1) {
    return const FirstRoundPlan(
      totalParticipants: 0,
      firstRoundPlayers: 0,
      firstRoundMatches: 0,
      firstRoundByes: 0,
      nextRoundSize: 0,
      repechageNeeded: 0,
    );
  }

  if (useRepechage) {
    final bool hasOddBye = totalParticipants.isOdd;
    final int matches = totalParticipants ~/ 2;
    final int naturalQualifiers = matches + (hasOddBye ? 1 : 0);
    final int nextRoundSize = nextPowerOfTwo(naturalQualifiers);
    // Invariant mathématique : nextPowerOfTwo(x) - x < x pour tout x >= 1,
    // donc repechageNeeded < naturalQualifiers <= matches + 1. Il y a donc
    // toujours assez de perdants du 1er tour pour fournir les repêchés
    // nécessaires, sans jamais dépasser leur nombre.
    final int repechageNeeded = nextRoundSize - naturalQualifiers;

    return FirstRoundPlan(
      totalParticipants: totalParticipants,
      firstRoundPlayers: totalParticipants,
      firstRoundMatches: matches,
      firstRoundByes: hasOddBye ? 1 : 0,
      nextRoundSize: nextRoundSize,
      repechageNeeded: repechageNeeded,
    );
  }

  final int bracketSize = nextPowerOfTwo(totalParticipants);
  final int byes = bracketSize - totalParticipants;
  final int firstRoundPlayers = totalParticipants - byes;

  return FirstRoundPlan(
    totalParticipants: totalParticipants,
    firstRoundPlayers: firstRoundPlayers,
    firstRoundMatches: firstRoundPlayers ~/ 2,
    firstRoundByes: byes,
    nextRoundSize: bracketSize ~/ 2,
    repechageNeeded: 0,
  );
}


/// Résultat de la validation d'un score de match par rapport aux
/// [MatchRules] de la phase concernée.
class ScoreValidationResult {
  final bool isValid;
  final String? errorKey; // clé de traduction, non nulle si invalide

  const ScoreValidationResult._(this.isValid, this.errorKey);

  factory ScoreValidationResult.valid() => const ScoreValidationResult._(true, null);

  factory ScoreValidationResult.invalid(String errorKey) =>
      ScoreValidationResult._(false, errorKey);
}

/// Valide un score de match complet ("6-4;3-6;7-5") par rapport aux
/// [MatchRules] applicables : format, victoire légitime de chaque set
/// (seuil de points atteint, écart de 2 points si requis), et cohérence
/// du nombre de sets avec [MatchRules.setsToWin] (pas de set en trop une
/// fois le match déjà décidé, pas de match laissé incomplet).
ScoreValidationResult validateMatchScore(String score, MatchRules rules) {
  final trimmed = score.trim();
  if (trimmed.isEmpty) {
    return ScoreValidationResult.invalid('score_empty');
  }

  final setStrings = trimmed.split(';');

  int player1SetsWon = 0;
  int player2SetsWon = 0;

  for (final rawSet in setStrings) {
    final setStr = rawSet.trim();
    final parts = setStr.split('-');
    if (parts.length != 2) {
      return ScoreValidationResult.invalid('score_format_incorrect');
    }

    final p1 = int.tryParse(parts[0].trim());
    final p2 = int.tryParse(parts[1].trim());
    if (p1 == null || p2 == null || p1 < 0 || p2 < 0) {
      return ScoreValidationResult.invalid('score_format_incorrect');
    }

    if (p1 == p2) {
      return ScoreValidationResult.invalid('score_set_tied');
    }

    final winnerScore = p1 > p2 ? p1 : p2;
    final loserScore = p1 > p2 ? p2 : p1;

    if (winnerScore < rules.pointsPerSet) {
      return ScoreValidationResult.invalid('score_set_incomplete');
    }

    if (rules.winByTwo && (winnerScore - loserScore) < 2) {
      return ScoreValidationResult.invalid('score_set_win_by_two');
    }

    // Le match était déjà décidé avant ce set : il n'aurait pas dû être joué.
    if (player1SetsWon >= rules.setsToWin || player2SetsWon >= rules.setsToWin) {
      return ScoreValidationResult.invalid('score_extra_sets');
    }

    if (p1 > p2) {
      player1SetsWon++;
    } else {
      player2SetsWon++;
    }
  }

  if (player1SetsWon < rules.setsToWin && player2SetsWon < rules.setsToWin) {
    return ScoreValidationResult.invalid('score_match_incomplete');
  }

  return ScoreValidationResult.valid();
}

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

/// Symétrique de [getWinner] : renvoie le joueur perdant du match.
/// Utile pour qualifier les demi-finalistes battus vers la petite finale.
String getLoser(MatchTournament match) {
  if (match.score == "") {
    return "";
  }

  final winner = getWinner(match);
  return winner == match.player1 ? match.player2 : match.player1;
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

// Méthode pour afficher une alerte d'erreur
  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('error').tr(),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Ok'.tr()),
            ),
          ],
        );
      },
    );
  }

Future<bool?> showAskDialog(BuildContext context, String message) async {
      return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('attention').tr(),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); 
              },
              child: Text('Yes').tr(),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(false); 
            },
            child: Text('No').tr())
          ],
        );
      },
    );
  }

  Future<bool?> showInfoDialog(BuildContext context, String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('information').tr(),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); 
              },
              child: Text('Ok').tr(),
            )
          ],
        );
      },
    );
  }




  void showDialogTournament(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("success_creation".tr()),
          content: Text("tournament_created".tr()),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                Navigator.of(context)
                    .pop(); // Ferme la page de creation du tournoi
              },
              child: Text('Ok'.tr()),
            ),
          ],
        );
      },
    );
  }

/// Dialogue de saisie du nom d'affichage de l'utilisateur, utilisé pour
/// relier son compte aux matchs où il apparaît (les participants d'un
/// tournoi étant des noms libres tapés par le créateur, pas des emails).
///
/// [mandatory] empêche la fermeture par tap en dehors du dialogue (le
/// bouton retour Android peut toutefois toujours le fermer ; c'est un
/// compromis volontaire pour ne pas dépendre d'API de pop récentes).
Future<void> showDisplayNameDialog(
  BuildContext context, {
  bool mandatory = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final controller = TextEditingController(text: user?.displayName ?? '');

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: !mandatory,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('display_name_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('display_name_explanation'.tr()),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'display_name_label'.tr()),
            ),
          ],
        ),
        actions: [
          if (!mandatory)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('cancel'.tr()),
            ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: Text('valid'.tr()),
          ),
        ],
      );
    },
  );

  if (result != null && result.isNotEmpty && user != null) {
    await user.updateDisplayName(result);
    await user.reload();
  }
}

