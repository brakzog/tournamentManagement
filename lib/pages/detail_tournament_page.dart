import 'dart:math';

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

class DetailTournamentPage extends StatefulWidget {
  final Tournament tournament;
  final bool inProgress;

  const DetailTournamentPage({
    super.key,
    required this.tournament,
    required this.inProgress,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DetailTournamentScreenState createState() =>
      // ignore: no_logic_in_create_state
      _DetailTournamentScreenState(tournament: tournament);
}

class _DetailTournamentScreenState extends State<DetailTournamentPage>
    with TickerProviderStateMixin {
  Tournament tournament;
  late TabController _tabController;
  String _selectedPoule = 'A'; // valeur de la poule sélectionnée

  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  // Get reference to tournament table from firebase
  DatabaseReference tournamentRef =
      FirebaseDatabase.instance.ref().child("tournois");

  _DetailTournamentScreenState({required this.tournament});

  Widget rectangleWidget(String a) {
    return InkWell(
      onTap: () {
        if (kDebugMode) {
          print('clicked');
        }
      },
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.blue[100]!, spreadRadius: 1),
            ],
          ),
          child: Text(a)),
    );
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    builder
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails du Tournoi"),
        // Ajoutez le TabBar à l'appBar
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Phase de Poule"),
            Tab(text: "Arbre de Déroulement"),
          ],
        ),
      ),
      // Utilisez le TabBarView pour afficher le contenu de chaque onglet
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: [
          // Page pour les matchs de poule
          _buildPoolMatchesPage(),
          // Page pour l'arbre de déroulement des matchs
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.01,
              maxScale: 5.6,
              child: Center(
                child: GraphView(
                  builder: (node) =>
                      rectangleWidget((node as TournamentNode).label),
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
      ),
    );
  }

  TournamentNode getTournamentNode(
    int id,
    EndTournament endTournament,
    int index,
    TournamentPhase phase,
    bool player1,
  ) {
    switch (phase) {
      case TournamentPhase.quart:
        if (endTournament.quarterFinalList.isEmpty) {
          return TournamentNode(id, "<player $id>");
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
          return TournamentNode(id, "<player $index>");
        }
        if (player1) {
          return TournamentNode(id, endTournament.semiFinalist[index].player1);
        } else {
          return TournamentNode(id, endTournament.semiFinalist[index].player2);
        }
    }
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

  List<MatchTournament> getMatchListFromPoule() {
    List<Poule> pouleList = tournament.pouleList;
    if (pouleList.isEmpty) {
      return [];
    }
    Poule findPoule =
        pouleList.where((element) => element.name == _selectedPoule).first;

    return findPoule.matchList;
  }

  Widget _buildPoolMatchesPage() {
    // Récupérer les matchs de poule depuis les données du tournoi
    final List<MatchTournament> matchList = getMatchListFromPoule();
    final bool isEmpty = tournament.pouleList.isEmpty;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEmpty)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  tournament.pouleList
                      .addAll(generatePools(tournament.participants));
                });
              },
              child: const Text("Démarrer le tournoi"),
            ),
          if (isEmpty) _buildParticipantList(),
          if (!isEmpty) _buildPouleSelector(),
          if (!isEmpty)
            _buildRanking(tournament.pouleList
                .where((element) => element.name == _selectedPoule)
                .first),
          const SizedBox(height: 16.0),
          ...[
            _buildMatches(matchList),
            const SizedBox(height: 16.0),
            if (widget.inProgress && tournament.pouleList.isNotEmpty)
              ElevatedButton(
                  child: const Text("Saisir des résultats"),
                  onPressed: () => showMatchResultDialog(
                        context,
                        tournament,
                        tournamentRef,
                        "",
                        "",
                      )),
          ],
        ],
      ),
    );
  }

  void showMatchResultDialog(BuildContext context, Tournament tournament,
      DatabaseReference tournamentRef, String player1, String player2) {
    Poule currentPoule = (tournament.pouleList
        .where((element) => element.name == _selectedPoule)).first;

    // Variables pour stocker les sélections des joueurs
    String selectedPlayer1 =
        (player1 != "" ? player1 : currentPoule.playerList.first);
    String selectedPlayer2 =
        (player2 != "" ? player2 : currentPoule.playerList.last);

    // Contrôleur pour le champ de texte
    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Saisi des résultats de match'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown pour le joueur 1
              DropdownButton<String>(
                value: selectedPlayer1,
                hint: const Text('Sélectionnez le joueur 1'),
                onChanged: (String? value) {
                  selectedPlayer1 = value!;

                  Navigator.of(context).pop();
                  showMatchResultDialog(context, tournament, tournamentRef,
                      value, selectedPlayer2);
                },
                items: currentPoule.playerList
                    .map<DropdownMenuItem<String>>((String player) {
                  return DropdownMenuItem<String>(
                    value: player,
                    child: Text(player),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Dropdown pour le joueur 2
              DropdownButton<String>(
                value: selectedPlayer2,
                hint: const Text('Sélectionnez le joueur 2'),
                onChanged: (String? value) {
                  selectedPlayer2 = value!;

                  Navigator.of(context).pop();
                  showMatchResultDialog(
                    context,
                    tournament,
                    tournamentRef,
                    selectedPlayer1,
                    value,
                  );
                },
                items: currentPoule.playerList
                    .map<DropdownMenuItem<String>>((String player) {
                  return DropdownMenuItem<String>(
                    value: player,
                    child: Text(player),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Champ de texte pour le score
              TextField(
                controller: scoreController,
                decoration: const InputDecoration(labelText: 'Entrez le score'),
              ),
            ],
          ),
          actions: [
            // Bouton valider
            InkWell(
              onTap: () async {
                // Traitez les résultats ici
                DatabaseReference selectedPouleRef = tournamentRef
                    .child(tournament.name)
                    .child('pouleList')
                    .child(_selectedPoule);

                bool matchExists = await checkMatchExists(
                    selectedPlayer1, selectedPlayer2, selectedPouleRef);
                if (matchExists) {
                  // ignore: use_build_context_synchronously
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Erreur'),
                        content: Text(
                            'Le match entre $selectedPlayer1 et $selectedPlayer2 a déjà été joué.'),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  if (isValidScoreFormat(scoreController.text)) {
                    // Le format du score est valide, ajoutez le nouveau match à la liste des matchs dans Firebase
                    MatchTournament newMatch = MatchTournament(
                      player1: selectedPlayer1,
                      player2: selectedPlayer2,
                      score: scoreController.text,
                    );
                    updateScore(selectedPouleRef, newMatch);

                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();
                  } else {
                    // ignore: use_build_context_synchronously
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Erreur'),
                          content: const Text(
                              'Le format du score est incorrect. Utilisez le format Xi-Yi;Xi+1-Yi+1;...'),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
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

  void updateScore(
      DatabaseReference selectedPouleRef, MatchTournament newMatch) {
    selectedPouleRef.once().then((snapshot) {
      // Vérifiez si l'événement contient des données
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> matches =
            snapshot.snapshot.value as Map<dynamic, dynamic>;

        // Parcourir les matches
        matches.forEach((key, matchListMap) {
          int i = 0;
          // ignore: avoid_function_literals_in_foreach_calls
          (matchListMap as List<Object?>).forEach((element) async {
            Map<Object?, Object?> currentMap = element as Map<Object?, Object?>;
            if (currentMap['player1'] == newMatch.player1 &&
                currentMap['player2'] == newMatch.player2) {
              // Correspondance trouvée, mettre à jour le score
              await selectedPouleRef
                  .child("matchs")
                  .child("$i")
                  .update(newMatch.toJson());
              setState(() {
                tournament.updatePoule(_selectedPoule, newMatch.player1,
                    newMatch.player2, newMatch.score);
              });
            } else if (element['player2'] == newMatch.player1 &&
                element['player1'] == newMatch.player2) {
              // Correspondance trouvée, mettre à jour le score
              await selectedPouleRef
                  .child("matchs")
                  .child("$i")
                  .update(newMatch.toJson());

              setState(() {
                tournament.updatePoule(_selectedPoule, newMatch.player1,
                    newMatch.player2, newMatch.score);
              });
            }
            i++;
          });
        });
      }
    });
  }

// Fonction pour vérifier le format du score
  bool isValidScoreFormat(String score) {
    // Utilisez une expression régulière pour vérifier le format du score
    // Ici, nous utilisons une expression régulière simple pour le format Xi-Yi;Xi+1-Yi+1;...
    RegExp regex = RegExp(r'^\d+-\d+(;\d+-\d+)*$');
    return regex.hasMatch(score);
  }

  // Méthode pour vérifier si un match existe déjà
  Future<bool> checkMatchExists(String player1, String player2,
      DatabaseReference databaseReference) async {
    DataSnapshot snapshot =
        (await databaseReference.child('matchs').once()).snapshot;
    List<Object?> matches = snapshot.value as List<Object?>;

    // Parcourir les matchs pour vérifier si le match existe déjà
    for (var match in matches) {
      Map currentMatch = match as Map<Object?, Object?>;
      if (currentMatch["score"] == "") {
        continue;
      }
      if (currentMatch['player1'] == player1 &&
          currentMatch['player2'] == player2) {
        return true;
      } else if (currentMatch['player1'] == player2 &&
          currentMatch['player2'] == player1) {
        return true;
      }
    }

    return false;
  }

  Widget _buildPouleSelector() {
    List<Poule> sortedPoules = List.from(tournament.pouleList);
    sortedPoules.sort((a, b) => a.name.compareTo(b.name));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Choix de la poule"),
        const SizedBox(width: 8.0),
        DropdownButton<String>(
          value: _selectedPoule,
          items: sortedPoules.map((poule) {
            return DropdownMenuItem<String>(
              value: poule.name,
              child: Text(poule.name),
            );
          }).toList(),
          onChanged: (selectedPoule) {
            setState(() {
              _selectedPoule = selectedPoule!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMatches(List<MatchTournament> matchList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("Matchs de Poule"),
        ),
        const SizedBox(height: 8.0),
        ...matchList.map((e) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("${e.player1} VS ${e.player2} : ${e.score}"),
            )),
      ],
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
          const Text("Classement"),
          const SizedBox(height: 8.0),
          // Utiliser la méthode map pour transformer chaque position en widget Text
          ...ranking.map((position) => Text(position)),
        ],
      ),
    );
  }

  List<MatchTournament> generateMatches(List<String> userList) {
    List<MatchTournament> matches = [];
    for (int i = 0; i < userList.length - 1; i++) {
      for (int j = i + 1; j < userList.length; j++) {
        MatchTournament match = MatchTournament(
          player1: userList[i],
          player2: userList[j],
          score: '',
        );
        matches.add(match);
      }
    }

    return matches;
  }

  List<Poule> generatePools(List<String> userList) {
    List<String> shuffledUsers = List.from(userList)..shuffle();

    int numberOfGroups = 4;
    int usersPerGroup = shuffledUsers.length ~/ numberOfGroups;
    int remainingUsers = shuffledUsers.length % numberOfGroups;

    List<List<String>> userGroups = List.generate(
      numberOfGroups,
      (index) {
        int start = index * usersPerGroup + min(index, remainingUsers);
        int end = (index + 1) * usersPerGroup + min(index + 1, remainingUsers);
        return shuffledUsers.sublist(start, end);
      },
    );

    List<Poule> poules = List.generate(
      4,
      (index) {
        List<String> usersInPoule = userGroups[index];
        List<MatchTournament> matchesInPoule = generateMatches(usersInPoule);

        return Poule(
          name: String.fromCharCode('A'.codeUnitAt(0) + index),
          playerList: usersInPoule,
          matchList: matchesInPoule,
        );
      },
    );
    // Référence à l'emplacement où vous souhaitez enregistrer les poules
    DatabaseReference poulesRef =
        tournamentRef.child(tournament.name).child('pouleList');

    // Convertir la liste de poules en une liste de maps
    List<Map<String, dynamic>> poulesData =
        poules.map((poule) => poule.toJson()).toList();
    for (var currentElement in poules) {
      Map<String, dynamic> currentPouleData = poulesData
          .where((element) => element["name"] == currentElement.name)
          .first;
      currentPouleData.remove("name");
      poulesRef.child(currentElement.name).set(currentPouleData);
    }

    return poules;
  }

  Widget _buildParticipantList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Text("Liste des participants"),
      ),
      const SizedBox(height: 8.0),
      ...tournament.participants.map((item) {
        return Text(item);
        // Ajoutez d'autres éléments de liste ici si nécessaire
      }),
    ]);
  }
}

enum TournamentPhase { quart, semi }
