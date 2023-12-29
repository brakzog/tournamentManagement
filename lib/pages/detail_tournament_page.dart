import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';

class DetailTournamentPage extends StatefulWidget {
  // Vous pouvez passer les données du tournoi ici depuis l'écran précédent
  final Tournament tournament;
  final bool inProgress;

  const DetailTournamentPage({
    super.key,
    required this.tournament,
    required this.inProgress,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DetailTournamentScreenState createState() => _DetailTournamentScreenState();
}

class _DetailTournamentScreenState extends State<DetailTournamentPage>
    with TickerProviderStateMixin {
  // Définissez un contrôleur pour le TabController
  late TabController _tabController;
  String _selectedPoule = 'A'; // Gardera la valeur de la poule sélectionnée

  // Get reference to tournament table from firebase
  DatabaseReference tournamentRef =
      FirebaseDatabase.instance.ref().child("tournois");

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

  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails du Tournoi"),
        // Ajoutez le TabBar à l'appBar
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Matchs de Poule"),
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
                  graph: createTournamentTree(widget.tournament.finalMatchList),
                  /* algorithm: BuchheimWalkerAlgorithm(TournamentNode.builder,
                    TreeEdgeRenderer(TournamentNode.builder)),*/
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

  String getWinner(MatchTournament match) {
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

  Graph createTournamentTree(EndTournament endTournament) {
    final Graph graph = Graph()..isTree = true;

    final TournamentNode winnerNode =
        TournamentNode(0, "Winner: ${getWinner(endTournament.finalMatch)}");

    final TournamentNode finalPlayer1Node =
        TournamentNode(1, endTournament.finalMatch.player1);

    final TournamentNode finalPlayer2Node =
        TournamentNode(2, endTournament.finalMatch.player2);

    final TournamentNode semiPlayer1Node =
        TournamentNode(3, endTournament.semiFinalist[0].player1);
    final TournamentNode semiPlayer2Node =
        TournamentNode(4, endTournament.semiFinalist[0].player2);
    final TournamentNode semiPlayer3Node =
        TournamentNode(5, endTournament.semiFinalist[1].player1);
    final TournamentNode semiPlayer4Node =
        TournamentNode(6, endTournament.semiFinalist[1].player2);

    final TournamentNode quarterPlayer1Node =
        TournamentNode(7, endTournament.quarterFinalList[0].player1);
    final TournamentNode quarterPlayer2Node =
        TournamentNode(8, endTournament.quarterFinalList[0].player2);
    final TournamentNode quarterPlayer3Node =
        TournamentNode(9, endTournament.quarterFinalList[1].player1);
    final TournamentNode quarterPlayer4Node =
        TournamentNode(10, endTournament.quarterFinalList[1].player2);
    final TournamentNode quarterPlayer5Node =
        TournamentNode(11, endTournament.quarterFinalList[2].player1);
    final TournamentNode quarterPlayer6Node =
        TournamentNode(12, endTournament.quarterFinalList[2].player2);
    final TournamentNode quarterPlayer7Node =
        TournamentNode(13, endTournament.quarterFinalList[3].player1);
    final TournamentNode quarterPlayer8Node =
        TournamentNode(14, endTournament.quarterFinalList[3].player2);

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
    List<Poule> pouleList = widget.tournament.pouleList;
    Poule findPoule =
        pouleList.where((element) => element.name == _selectedPoule).first;

    return findPoule.matchList;
  }

  Widget _buildPoolMatchesPage() {
    // Récupérer les matchs de poule depuis les données du tournoi
    final List<MatchTournament> matchList = getMatchListFromPoule();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPouleSelector(),
        const SizedBox(height: 16.0),
        ...[
          _buildMatches(matchList),
          const SizedBox(height: 16.0),
          _buildRanking(widget.tournament.pouleList
              .where((element) => element.name == _selectedPoule)
              .first),
          const SizedBox(
            height: 50,
          ),
          if (widget.inProgress)
            ElevatedButton(
                child: const Text("Saisir des résultats"),
                onPressed: () => showMatchResultDialog(
                      context,
                      widget.tournament,
                      tournamentRef,
                    )),
        ],
      ],
    );
  }

  void showMatchResultDialog(BuildContext context, Tournament tournament,
      DatabaseReference tournamentRef) {
    Poule currentPoule = (tournament.pouleList
        .where((element) => element.name == _selectedPoule)).first;

    // Variables pour stocker les sélections des joueurs
    String selectedPlayer1 = currentPoule.playerList.first;
    String selectedPlayer2 = currentPoule.playerList.last;

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
                value: currentPoule.playerList.first,
                hint: const Text('Sélectionnez le joueur 1'),
                onChanged: (String? value) {
                  selectedPlayer1 = value!;
                  Navigator.of(context).pop();
                  showMatchResultDialog(
                    context,
                    tournament,
                    tournamentRef,
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

              // Dropdown pour le joueur 2
              DropdownButton<String>(
                value: currentPoule.playerList.last,
                hint: const Text('Sélectionnez le joueur 2'),
                onChanged: (String? value) {
                  selectedPlayer2 = value!;
                  Navigator.of(context).pop();
                  showMatchResultDialog(
                    context,
                    tournament,
                    tournamentRef,
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
                DatabaseReference test = tournamentRef
                    .child(tournament.name)
                    .child('pouleList')
                    .child(_selectedPoule);

                bool matchExists = await checkMatchExists(
                    selectedPlayer1, selectedPlayer2, test);
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
                      player1: selectedPlayer1!,
                      player2: selectedPlayer2!,
                      score: scoreController.text,
                    );

                    test.child('matchs').push().set(newMatch.toJson());
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

  // Méthode pour vérifier si un match existe déjà
  Future<bool> checkMatchExists(String player1, String player2,
      DatabaseReference databaseReference) async {
    DataSnapshot snapshot =
        (await databaseReference.child('matchs').once()).snapshot;
    List<Object?> matches = snapshot.value as List<Object?>;

    // Parcourir les matchs pour vérifier si le match existe déjà
    for (var match in matches) {
      Map currentMatch = match as Map<Object?, Object?>;
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
    return Row(
      children: [
        const Text("Choix de la poule"),
        const SizedBox(width: 8.0),
        DropdownButton<String>(
          value: _selectedPoule,
          items: widget.tournament.pouleList.map((poule) {
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Matchs de Poule"),
        const SizedBox(height: 8.0),
        ...matchList
            .map((e) => Text("${e.player1} VS ${e.player2} : ${e.score}")),
      ],
    );
  }

  Widget _buildRanking(Poule poule) {
    // Calculer le classement en fonction des victoires dans les matchs
    List<String> ranking = calculateRanking(poule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Classement"),
        const SizedBox(height: 8.0),
        // Utiliser la méthode map pour transformer chaque position en widget Text
        ...ranking.map((position) => Text(position)),
      ],
    );
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
}

class TournamentNode extends Node {
  final String label;

  TournamentNode(int super.id, this.label) : super.Id();

  static Widget builder(BuildContext context, Node node, Map<int, Node> graph) {
    return Builder(
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue, // Couleur du nœud
          ),
          child: Center(
            child: Text(
              (node as TournamentNode).label,
              style: const TextStyle(color: Colors.white), // Couleur du texte
            ),
          ),
        );
      },
    );
  }
}
