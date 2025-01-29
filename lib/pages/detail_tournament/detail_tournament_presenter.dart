import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/graphView/GraphView.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/utils.dart';
import 'package:tournament_management/widgets/tournament_node.dart';

import 'detail_tournament_viewmodel.dart';

class DetailTournamentPresenter {
  final DetailTournamentViewModel viewModel;
  final Tournament tournament;
  final Function setState;
  final bool inProgress;  // La valeur inProgress est déjà passée dans le constructeur
  String selectedPoule = "A";
  late TabController tabController;

  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();


  DetailTournamentPresenter(
    this.tournament,
    this.setState,
    this.inProgress,
    this.viewModel,
  ) {
    builder
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT);
  }

  void initTabController(TickerProvider vsync) {
    tabController = TabController(length: 2, vsync: vsync);
  }

  Widget buildDetailTournament(BuildContext context,) {
    return Scaffold(
    appBar: AppBar(
      title: const Text("detail_tournament").tr(),
      bottom: TabBar(
        controller: tabController,
        tabs: [
          Tab(text: "poule_phase".tr()),
          Tab(text: "arbre_deroulement".tr()),
        ],
      ),
    ),
    body: TabBarView(
      controller: tabController,
      children: [
        _buildPoolMatchesPage(context),
        _buildArbreDeDeroulementTab(context),
      ],
    ),
  );
}

//================================================ POULES ==========================================================================================

Widget _buildPoolMatchesPage(BuildContext context) {
  final bool isEmpty = tournament.pouleList.isEmpty;
  final List<MatchTournament> matchList = getMatchListFromPoule();

  final bool shouldDisplayStartButton = isEmpty;
  final bool shouldDisplayPouleSelector = !isEmpty;
  final bool shouldDisplayMatchResultButton = inProgress && !isEmpty;

  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shouldDisplayStartButton) _buildStartTournamentButton(),
        if (shouldDisplayStartButton) _buildParticipantList(),
        if (shouldDisplayPouleSelector) buildPouleSelector(),
        if (shouldDisplayPouleSelector) _buildRankingSection(),
        const SizedBox(height: 16.0),
        _buildMatchListSection(matchList),
        const SizedBox(height: 16.0),
        if (shouldDisplayMatchResultButton) _buildMatchResultButton(context),
      ],
    ),
  );
}


Widget _buildStartTournamentButton() {
  return ElevatedButton(
    onPressed: () async {
      // Appeler la méthode du ViewModel pour générer les poules
      await viewModel.generatePoolsAndUpdateTournament(tournament);

      // Mettre à jour l'état de la vue (présenter une nouvelle liste de poules)
      setState(() {
        // Cela déclenche la mise à jour de la vue sans modifier la logique métier ici
      });
    },
    child: const Text("Démarrer le tournoi"),
  );
}


Widget _buildParticipantList() {
  return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Text("participants_list".tr()),
      ),
      const SizedBox(height: 8.0),
      // Utilisation de ListView pour gérer une longue liste de manière performante
      ...tournament.participants.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(item),
        );
      }).toList(),
  ]);
}


Widget buildPouleSelector() {
  List<Poule> sortedPoules = List.from(tournament.pouleList);
  sortedPoules.sort((a, b) => a.name.compareTo(b.name));
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("poule_choice".tr()),
      const SizedBox(width: 8.0),
      DropdownButton<String>(
        value: selectedPoule,
        items: sortedPoules.map((poule) {
          return DropdownMenuItem<String>(
            value: poule.name,
            child: Text(poule.name),
          );
        }).toList(),
        onChanged: (selectedPoule) {
          if(selectedPoule != null) updateSelectedPoule(selectedPoule);
        },
      ),
    ],
  );
}

void updateSelectedPoule(String newPoule) {
  setState(() {
    selectedPoule = newPoule;
  });
}


Widget _buildRankingSection() {
  return _buildRanking(
    tournament.pouleList.where((element) => element.name == selectedPoule).first,
  );
}

Widget _buildMatchListSection(List<MatchTournament> matchList) {
  return _buildMatches(matchList);
}

Widget _buildMatches(List<MatchTournament> matchList) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Text("poule_matches".tr()),
      ),
      const SizedBox(height: 8.0),
      ...matchList.map((e) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text("${e.player1} VS ${e.player2} : ${e.score}"),
        ),
      ),
    ],
  );
}


  Widget _buildMatchResultButton(BuildContext context) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");
    return ElevatedButton(
      child: Text("result_match_input".tr()),
      onPressed: () => showMatchResultDialog(
        context,
        tournament,
        tournamentRef,
        "",
        "",
      ),
    );
  }


  Widget _buildRanking(Poule poule) {
    // Calculer le classement en fonction des victoires dans les matchs
    List<String> ranking = calculateRanking(poule);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("rank".tr()),
          const SizedBox(height: 8.0),
          // Utiliser la méthode map pour transformer chaque position en widget Text
          ...ranking.map((position) => Text(position)),
        ],
      ),
    );
  }

  List<String> calculateRanking(Poule poule) {
    // Initialisation d'un map pour stocker le nombre de victoires de chaque joueur
    Map<String, int> victories = {};

    // Parcourir la liste des matchs de la poule
    for (MatchTournament match in poule.matchList) {
      // Découper le score pour obtenir les sets
      List<String> sets = match.score.split(';');

      // Calculer les victoires pour chaque joueur
      int victoriesPlayer1 = 0;
      int victoriesPlayer2 = 0;

      // Parcourir chaque set
      for (String set in sets) {
        List<String> scores = set.split('-');
        if (scores.length == 2) {
          // Comparer les scores pour chaque set
          victoriesPlayer1 += int.parse(scores[0]) > int.parse(scores[1]) ? 1 : 0;
          victoriesPlayer2 += int.parse(scores[1]) > int.parse(scores[0]) ? 1 : 0;
        }
      }

      // Déterminer le gagnant et mettre à jour les victoires
      String winner = victoriesPlayer1 > victoriesPlayer2 ?
       match.player1 : victoriesPlayer2 > victoriesPlayer1 ? match.player2: '';

      // Mise à jour du nombre de victoires pour chaque joueur
      victories[match.player1] = (victories[match.player1] ?? 0) + (winner == match.player1 ? 1 : 0);
      victories[match.player2] = (victories[match.player2] ?? 0) + (winner == match.player2 ? 1 : 0);
    }

    // Trier les joueurs par nombre de victoires décroissantes
    List<MapEntry<String, int>> sortedEntries = victories.entries.toList()
      ..sort((entry1, entry2) => entry2.value.compareTo(entry1.value));
    
    // Construire la liste du classement sous forme de chaîne de texte
    List<String> ranking = sortedEntries
      .asMap()
      .map((index, entry) => MapEntry(index + 1, "${entry.key} - ${entry.value} victoires"))
      .values
      .toList();
    return ranking;
  }

  List<MatchTournament> getMatchListFromPoule() {
    List<Poule> pouleList = tournament.pouleList;
    if (pouleList.isEmpty) {
      return [];
    }
    Poule findPoule =
        pouleList.where((element) => element.name == selectedPoule).first;

    return findPoule.matchList;
  }

  void showMatchResultDialog(
    BuildContext context,
    Tournament tournament,
    DatabaseReference tournamentRef,
    String player1,
    String player2,
  ) {
    Poule currentPoule = tournament.pouleList.firstWhere(
        (element) => element.name == selectedPoule);

    // Variables pour stocker les sélections des joueurs
    String selectedPlayer1 = player1.isNotEmpty ? player1 : currentPoule.playerList.first;
    String selectedPlayer2 = player2.isNotEmpty ? player2 : currentPoule.playerList.last;

    // Contrôleur pour le champ de texte
    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('result_match_input'.tr()),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerDropdown(
                context,
                currentPoule.playerList,
                selectedPlayer1,
                (value) {
                  selectedPlayer1 = value!;
                  Navigator.of(context).pop();
                  showMatchResultDialog(context, tournament, tournamentRef, value, selectedPlayer2);
                },
              ),
              const SizedBox(height: 10),
              _buildPlayerDropdown(
                context,
                currentPoule.playerList,
                selectedPlayer2,
                (value) {
                  selectedPlayer2 = value!;
                  Navigator.of(context).pop();
                  showMatchResultDialog(context, tournament, tournamentRef, selectedPlayer1, value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: scoreController,
                decoration: InputDecoration(labelText: 'score_input'.tr()),
              ),
            ],
          ),
          actions: [
            InkWell(
              onTap: () async {
                // Traitez les résultats ici
                DatabaseReference selectedPouleRef = tournamentRef
                    .child(tournament.name)
                    .child('pouleList')
                    .child(selectedPoule);

                bool matchExists = await checkMatchExists(
                    selectedPlayer1, selectedPlayer2, selectedPouleRef);

                if (matchExists) {
                  String errorMessage = tr('matchAlreadyPlayed',args: [selectedPlayer1, selectedPlayer2],);
                  showErrorDialog(context, errorMessage);
                } else {
                  if (isValidScoreFormat(scoreController.text)) {
                    MatchTournament newMatch = MatchTournament(
                      player1: selectedPlayer1,
                      player2: selectedPlayer2,
                      score: scoreController.text,
                    );
                    updateScore(selectedPouleRef, newMatch);
                    Navigator.of(context).pop();
                  } else {
                    showErrorDialog(context, 'Le format du score est incorrect. Utilisez le format Xi-Yi;Xi+1-Yi+1;...');
                  }
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  // Fonction pour vérifier le format du score
  bool isValidScoreFormat(String score) {
    // Utilisez une expression régulière pour vérifier le format du score
    // Ici, nous utilisons une expression régulière simple pour le format Xi-Yi;Xi+1-Yi+1;...
    RegExp regex = RegExp(r'^\d+-\d+(;\d+-\d+)*$');
    return regex.hasMatch(score);
  }

  // Méthode pour construire le dropdown des joueurs
  Widget _buildPlayerDropdown(
    BuildContext context,
    List<String> playerList,
    String selectedPlayer,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButton<String>(
      value: selectedPlayer,
      hint: const Text('Sélectionnez un joueur'),
      onChanged: onChanged,
      items: playerList.map<DropdownMenuItem<String>>((String player) {
        return DropdownMenuItem<String>(
          value: player,
          child: Text(player),
        );
      }).toList(),
    );
  }

  


  void updateScore(DatabaseReference selectedPouleRef, MatchTournament newMatch) async {
    await viewModel.updateMatch(selectedPouleRef, newMatch);

    setState(() {
      tournament.updatePoule(selectedPoule, newMatch.player1, newMatch.player2, newMatch.score);
      if (isAllMatchPlayed()) {
        updateGraph();
      }
    });
  }

  void updateGraph() {
    // Calculez les classements des poules
    Map<String, List<String>> pouleRankings = {};

    for (var poule in tournament.pouleList) {
      var wins = calculateWins(poule.matchList, poule.playerList);
      pouleRankings[poule.name] = rankPlayers(wins);
    }

    // Créez les matchs pour les quarts de finale
    tournament.finalMatchList.quarterFinalList = createQuarterFinalBracket(pouleRankings);
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");

    saveQuarterFinalsToFirebase(tournamentRef, tournament.finalMatchList.quarterFinalList);
    setState(() {});
  }

  Map<String, int> calculateWins(List<MatchTournament> matches, List<String> players) {
    // Initialise le Map avec les joueurs et leur nombre de victoires à 0
    Map<String, int> wins = Map.fromIterable(players, value: (_) => 0);
    for (var match in matches) {
      var scoreParts = match.score.split(';');
      int player1Wins = 0;
      int player2Wins = 0;

      for (var score in scoreParts) {
        var setScores = score.split('-');
        if (setScores.length == 2) {
          // Parse les scores et gère les cas où le format pourrait être incorrect
          int player1Score = int.tryParse(setScores[0]) ?? 0;
          int player2Score = int.tryParse(setScores[1]) ?? 0;

          if (player1Score > player2Score) {
            player1Wins++;
          } else if (player2Score > player1Score) {
            player2Wins++;
          }
        }
      }

      // Incrémente les victoires du joueur gagnant
      if (player1Wins > player2Wins) {
        wins[match.player1] = (wins[match.player1] ?? 0) + 1;
      } else if (player2Wins > player1Wins) {
        wins[match.player2] = (wins[match.player2] ?? 0) + 1;
      }
    }

    return wins;
  }

  List<String> rankPlayers(Map<String, int> wins) {
      var sortedEntries = wins.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sortedEntries.map((e) => e.key).toList();
  }


  List<MatchTournament> createQuarterFinalBracket(Map<String, List<String>> pouleRankings) {
    List<MatchTournament> quarterFinals = [
      MatchTournament(
        player1: pouleRankings['A']![0],
        player2: pouleRankings['B']![1],
        score: '',
      ),
      MatchTournament(
        player1: pouleRankings['C']![0],
        player2: pouleRankings['D']![1],
        score: '',
      ),
      MatchTournament(
        player1: pouleRankings['B']![0],
        player2: pouleRankings['A']![1],
        score: '',
      ),
      MatchTournament(
        player1: pouleRankings['D']![0],
        player2: pouleRankings['C']![1],
        score: '',
      ),
    ];

    return quarterFinals;
  }

  void saveQuarterFinalsToFirebase(DatabaseReference tournamentRef, List<MatchTournament> quarterFinals) async {
    try {
      await tournamentRef.child(tournament.name).update({
        "quartFinal": quarterFinals.map((match) => match.toJson()).toList()});

      print("Les quarts de finale ont été enregistrés dans Firebase.");
    }  catch (e) {
      print("Erreur lors de l'enregistrement des quarts de finale : $e");
    }
  }


  bool isAllMatchPlayed() {
    for (var poule in tournament.pouleList) {
      for (var match in poule.matchList) {
        if (match.score.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  // Méthode pour vérifier si un match existe déjà
  Future<bool> checkMatchExists(String player1, String player2, DatabaseReference databaseReference) async {
    try {
      DataSnapshot snapshot = (await databaseReference.child('matchs').once()).snapshot;
      List<Object?> matches = snapshot.value as List<Object?>;

      // Utilisation d'un Set pour vérifier rapidement si un match existe
      for (var match in matches) {
        if (match is! Map) continue;
        Map currentMatch = match as Map<Object?, Object?>;

        // Si le score est vide, on passe au match suivant
        if (currentMatch["score"] == "") continue;

        // Vérification de la présence du match
        String matchKey1 = '${currentMatch['player1']}-${currentMatch['player2']}';
        String matchKey2 = '${currentMatch['player2']}-${currentMatch['player1']}';
        String keyToCheck = '$player1-$player2';

        if (matchKey1 == keyToCheck || matchKey2 == keyToCheck) {
          return true;  // Match trouvé
        }
      }

      return false;  // Aucun match trouvé
    } catch (e) {
      print("Erreur lors de la vérification du match: $e");
      return false;  // Retourne false en cas d'erreur
    }
  }



  //================================================= ARBRE ===============================================================================


List<String> getPlayerList(List<MatchTournament> listMatch) {
  List<String> playerList = [];
  for(MatchTournament match in listMatch) {
    playerList.add(match.player1);
    playerList.add(match.player2);
  }
  return playerList;
}


void showMatchArbreDialog(
    BuildContext context,
    Tournament tournament,
    DatabaseReference tournamentRef,
    String player1,
    String player2,
  ) {
    List<String> playerList = List.empty();

    if(hasNotEmptyElements(tournament.finalMatchList.quarterFinalList)) {
      playerList = getPlayerList(tournament.finalMatchList.quarterFinalList);
    } else if (hasNotEmptyElements(tournament.finalMatchList.semiFinalist)) {
      playerList = getPlayerList(tournament.finalMatchList.semiFinalist);
    } else if (tournament.finalMatchList.finalMatch.score.isEmpty) {
      playerList = [tournament.finalMatchList.finalMatch.player1, tournament.finalMatchList.finalMatch.player2];
    }

    // Variables pour stocker les sélections des joueurs
    String selectedPlayer1 = player1.isNotEmpty ? player1 : playerList.first;
    String selectedPlayer2 = player2.isNotEmpty ? player2 : retrievePlayer(selectedPlayer1, tournament.finalMatchList);

    // Contrôleur pour le champ de texte
    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('result_match_input'.tr()),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerDropdown(
                context,
                playerList,
                selectedPlayer1,
                (value) {
                  selectedPlayer1 = value!;
                  selectedPlayer2 = retrievePlayer(selectedPlayer1, tournament.finalMatchList);
                  Navigator.of(context).pop();
                  showMatchArbreDialog(context, tournament, tournamentRef, value, selectedPlayer2);
                },
              ),
              const SizedBox(height: 10),
              _buildPlayerDropdown(
                context,
                playerList,
                selectedPlayer2,
                (value) {
                  selectedPlayer2 = value!;
                  selectedPlayer1 = retrievePlayer(selectedPlayer2, tournament.finalMatchList);
                  Navigator.of(context).pop();
                  showMatchArbreDialog(context, tournament, tournamentRef, selectedPlayer1, value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: scoreController,
                decoration: InputDecoration(labelText: 'score_input'.tr()),
              ),
            ],
          ),
          actions: [
            InkWell(
              onTap: () async { //TODO la suite ici!!!!!
                // Traitez les résultats ici
               /* DatabaseReference selectedPouleRef = tournamentRef
                    .child(tournament.name)
                    .child('pouleList')
                    .child(selectedPoule);

                bool matchExists = await checkMatchExists(
                    selectedPlayer1, selectedPlayer2, selectedPouleRef);

                if (matchExists) {
                  String errorMessage = tr('matchAlreadyPlayed',args: [selectedPlayer1, selectedPlayer2],);
                  showErrorDialog(context, errorMessage);
                } else {
                  if (isValidScoreFormat(scoreController.text)) {
                    MatchTournament newMatch = MatchTournament(
                      player1: selectedPlayer1,
                      player2: selectedPlayer2,
                      score: scoreController.text,
                    );
                    updateScore(selectedPouleRef, newMatch);
                    Navigator.of(context).pop();
                  } else {
                    showErrorDialog(context, 'Le format du score est incorrect. Utilisez le format Xi-Yi;Xi+1-Yi+1;...');
                  }
                }*/
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  String retrievePlayer(String selectedPlayer, EndTournament tournament) {
    String player = "";
    if (hasNotEmptyElements(tournament.quarterFinalList)) {
      for (MatchTournament match in tournament.quarterFinalList) {
        if(match.player1 == selectedPlayer) {
          player = match.player2;
          continue;
        } else if (match.player2 == selectedPlayer) {
          player = match.player1;
          continue;
        }
      }
    } else if (hasNotEmptyElements(tournament.semiFinalist)) {
      for (MatchTournament match in tournament.semiFinalist) {
        if(match.player1 == selectedPlayer) {
          player = match.player2;
          continue;
        } else if (match.player2 == selectedPlayer) {
          player = match.player1;
          continue;
        }
      }
    } else if (tournament.finalMatch.player1 == selectedPlayer) {
      player = tournament.finalMatch.player2;

    } else {
      player = tournament.finalMatch.player1;

    }
    return player;
  }


  Widget _buildArbreDeDeroulementTab(BuildContext context) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");
    return Column(
      children: [
        ElevatedButton(
          child: Text("result_match_input".tr()),
          onPressed: () => showMatchArbreDialog(
            context,
            tournament,
            tournamentRef,
            "",
            "",
          ),
        ),


        Expanded(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.01,
            maxScale: 5.6,
            child: Center(
              child: GraphView(
                builder: (node) => rectangleWidget((node as TournamentNode).label),
                graph: createTournamentTree(tournament.finalMatchList),
                algorithm: BuchheimWalkerAlgorithm(
                  builder,
                  TreeEdgeRenderer(builder),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget rectangleWidget(String a) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: Colors.blue[100]!, spreadRadius: 1),
          ],
        ),
        child: Text(a));
  }

  Graph createTournamentTree(EndTournament endTournament) {
    final Graph graph = Graph()..isTree = true;

    final TournamentNode winnerNode =
        TournamentNode(0, "Winner: ${getWinner(endTournament.finalMatch)}");

    final TournamentNode finalPlayer1Node =
        TournamentNode(1, endTournament.finalMatch.player1);

    final TournamentNode finalPlayer2Node =
        TournamentNode(2, endTournament.finalMatch.player2);

    final TournamentNode semiPlayer1Node =
        getTournamentNode(3, endTournament, 0, TournamentPhase.semi, true);
    final TournamentNode semiPlayer2Node =
        getTournamentNode(4, endTournament, 0, TournamentPhase.semi, false);
    final TournamentNode semiPlayer3Node =
        getTournamentNode(5, endTournament, 1, TournamentPhase.semi, true);
    final TournamentNode semiPlayer4Node =
        getTournamentNode(6, endTournament, 1, TournamentPhase.semi, false);

    final TournamentNode quarterPlayer1Node =
        getTournamentNode(7, endTournament, 0, TournamentPhase.quart, true);
    final TournamentNode quarterPlayer2Node =
        getTournamentNode(8, endTournament, 0, TournamentPhase.quart, false);
    final TournamentNode quarterPlayer3Node =
        getTournamentNode(9, endTournament, 1, TournamentPhase.quart, true);
    final TournamentNode quarterPlayer4Node =
        getTournamentNode(10, endTournament, 1, TournamentPhase.quart, false);
    final TournamentNode quarterPlayer5Node =
        getTournamentNode(11, endTournament, 2, TournamentPhase.quart, true);
    final TournamentNode quarterPlayer6Node =
        getTournamentNode(12, endTournament, 2, TournamentPhase.quart, false);
    final TournamentNode quarterPlayer7Node =
        getTournamentNode(13, endTournament, 3, TournamentPhase.quart, true);
    final TournamentNode quarterPlayer8Node =
        getTournamentNode(14, endTournament, 3, TournamentPhase.quart, false);

    graph.addEdge(winnerNode, finalPlayer1Node);
    graph.addEdge(winnerNode, finalPlayer2Node);
    

    graph.addEdge(finalPlayer1Node, semiPlayer1Node);
    graph.addEdge(finalPlayer1Node, semiPlayer2Node);
    graph.addEdge(finalPlayer2Node, semiPlayer3Node);
    graph.addEdge(finalPlayer2Node, semiPlayer4Node);
    

    graph.addEdge(semiPlayer1Node, quarterPlayer1Node);
    graph.addEdge(semiPlayer1Node, quarterPlayer2Node);
    graph.addEdge(semiPlayer2Node, quarterPlayer3Node);
    graph.addEdge(semiPlayer2Node, quarterPlayer4Node);
    graph.addEdge(semiPlayer3Node, quarterPlayer5Node);
    graph.addEdge(semiPlayer3Node, quarterPlayer6Node);
    graph.addEdge(semiPlayer4Node, quarterPlayer7Node);
    graph.addEdge(semiPlayer4Node, quarterPlayer8Node);
    return graph;
  }

  bool hasNotEmptyElements(List<MatchTournament> list) {
    for(MatchTournament currentMatch in list) {
      if (currentMatch.score.isEmpty ) return true;
    }
    return false;
  }


  TournamentNode getTournamentNode(int id, EndTournament endTournament, int index, TournamentPhase phase, bool player1,) {
    switch (phase) {
      case TournamentPhase.quart:
        if (endTournament.quarterFinalList.isEmpty) {
          return TournamentNode(id, "");
        }
        if (player1) {
          return TournamentNode(
              id, endTournament.quarterFinalList[index].player1);
        } else {
          return TournamentNode(
              id, endTournament.quarterFinalList[index].player2);
        }
      case TournamentPhase.semi:
        if (endTournament.semiFinalist.isEmpty) {
          return TournamentNode(id, "");
        }
        if (player1) {
          return TournamentNode(id, endTournament.semiFinalist[index].player1);
        } else {
          return TournamentNode(id, endTournament.semiFinalist[index].player2);
        }
    }
  }
}

