import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

/// Symétrique de [getWinner] : renvoie le joueur perdant du match.
/// Utile pour qualifier les demi-finalistes battus vers la petite finale.
String getLoser(MatchTournament match) {
  if (match.score == "") {
    return "";
  }

  final winner = getWinner(match);
  return winner == match.player1 ? match.player2 : match.player1;
}

/// Vérifie que le score respecte le format "Xi-Yi;Xi+1-Yi+1;..." attendu
/// partout dans l'app pour un score de match.
bool isValidScoreFormat(String score) {
  final RegExp regex = RegExp(r'^\d+-\d+(;\d+-\d+)*$');
  return regex.hasMatch(score);
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

