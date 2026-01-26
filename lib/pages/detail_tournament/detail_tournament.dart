import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tournament_management/graphView/GraphView.dart';
import 'package:tournament_management/models/end_tournament.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/models/tournament_phase.dart';
import 'package:tournament_management/utils.dart';
import 'package:tournament_management/widgets/tournament_node.dart';

import 'detail_tournament_viewmodel.dart';

class DetailTournament extends StatelessWidget {
  final bool inProgress;
  final Tournament tournament;

  const DetailTournament({
    super.key,
    required this.inProgress,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DetailTournamentViewModel(
        tournament: tournament,
        inProgress: inProgress,
      ),
      child: const _DetailTournamentScreen(),
    );
  }
}

class _DetailTournamentScreen extends StatefulWidget {
  const _DetailTournamentScreen({super.key});

  @override
  State<_DetailTournamentScreen> createState() =>
      _DetailTournamentScreenState();
}

class _DetailTournamentScreenState extends State<_DetailTournamentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();


    // 2 onglets : poules + arbre
    _tabController = TabController(length: 2, vsync: this);

    // Tabs -> state MVI
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final vm = context.read<DetailTournamentViewModel>();
      vm.onIntent(ChangeTabIntent(_tabController.index));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetailTournamentViewModel>();
    vm.init();
    final state = vm.state;

    // State -> tabs
    if (_tabController.index != state.tabIndex &&
        !_tabController.indexIsChanging) {
      _tabController.index = state.tabIndex;
    }

    if (state.deleteSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("detail_tournament").tr(),
        actions:[
          if (_canShowDeleteButton(state))
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                vm.onIntent(const DetailTournamentIntentDeleteRequested());
              },
            )

        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "poule_phase".tr()),
            Tab(text: "arbre_deroulement".tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          if (state.isLoading) const LinearProgressIndicator(),
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              padding: const EdgeInsets.all(8),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PoolPhaseTab(tabController: _tabController),
                const _BracketTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: vm.inProgress
          ? FloatingActionButton.extended(
        onPressed: () =>
            vm.onIntent(const GeneratePoolsIntent()),
        icon: const Icon(Icons.grid_view),
        label: Text("start_tournament".tr()),
      )
          : null,
    );
  }
}


bool _canShowDeleteButton(DetailTournamentState state) {
  final tournament = state.tournament; // adapte au nom exact dans ton state
  if (tournament == null) return false;

  // Récup de l'utilisateur courant (exemple avec FirebaseAuth)
  final currentUserId = FirebaseAuth.instance.currentUser?.email;
  if (currentUserId == null) return false;

  final isCreator = tournament.createdBy == currentUserId;

  // Condition 2 : le tournoi a une finale jouée
  final finalMatchFinished = tournament.finalMatchList.finalMatch.score;

  return isCreator && finalMatchFinished != null && finalMatchFinished != "";
}

// ======================================================================
//                          ONGLET POULES
// ======================================================================

class _PoolPhaseTab extends StatefulWidget {
  final TabController tabController;

  const _PoolPhaseTab({
    required this.tabController,
  });

  @override
  State<_PoolPhaseTab> createState() => _PoolPhaseTabState();
}

class _PoolPhaseTabState extends State<_PoolPhaseTab> {
  String selectedPoule = "A";

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetailTournamentViewModel>();
    final tournament = vm.tournament;

    final bool isEmpty = tournament.pouleList.isEmpty;
    final List<MatchTournament> matchList = getMatchListFromPoule(tournament);

    final bool shouldDisplayStartButton = isEmpty;
    final bool shouldDisplayPouleSelector = !isEmpty;
    final bool shouldDisplayMatchResultButton = vm.inProgress && !isEmpty;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shouldDisplayStartButton) _buildStartTournamentButton(vm),
          if (shouldDisplayStartButton) _buildParticipantList(tournament),
          if (shouldDisplayPouleSelector) buildPouleSelector(tournament),
          if (shouldDisplayPouleSelector) _buildRankingSection(tournament),
          const SizedBox(height: 16.0),
          _buildMatchListSection(matchList),
          const SizedBox(height: 16.0),
          if (shouldDisplayMatchResultButton)
            _buildMatchResultButton(context, tournament),
        ],
      ),
    );
  }

  // --- Bouton de démarrage / génération des poules ---

  Widget _buildStartTournamentButton(DetailTournamentViewModel vm) {
    return ElevatedButton(
      onPressed: () async {
        await vm.generatePoolsAndUpdateTournament();
        setState(() {
          // on force juste un rebuild, les données viennent déjà du ViewModel
        });
      },
      child: Text("start_tournament".tr()),
    );
  }

  // --- Liste des participants avant génération ---

  Widget _buildParticipantList(Tournament tournament) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("participants_list".tr()),
        ),
        const SizedBox(height: 8.0),
        ...tournament.participants.map(
              (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(item),
          ),
        ),
      ],
    );
  }

  // --- Sélecteur de poule ---

  Widget buildPouleSelector(Tournament tournament) {
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
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedPoule = value;
              });
            }
          },
        ),
      ],
    );
  }

  // --- Classement de la poule sélectionnée ---

  Widget _buildRankingSection(Tournament tournament) {
    final poule = tournament.pouleList
        .where((element) => element.name == selectedPoule)
        .first;
    return _buildRanking(poule);
  }

  Widget _buildRanking(Poule poule) {
    final ranking = calculateRanking(poule);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("rank".tr()),
          const SizedBox(height: 8.0),
          ...ranking.map((position) => Text(position)),
        ],
      ),
    );
  }

  List<String> calculateRanking(Poule poule) {
    Map<String, int> victories = {};

    for (MatchTournament match in poule.matchList) {
      if (match.score.isEmpty) continue;

      List<String> sets = match.score.split(';');

      int victoriesPlayer1 = 0;
      int victoriesPlayer2 = 0;

      for (String set in sets) {
        List<String> scores = set.split('-');
        if (scores.length == 2) {
          final s1 = int.tryParse(scores[0]) ?? 0;
          final s2 = int.tryParse(scores[1]) ?? 0;

          if (s1 > s2) {
            victoriesPlayer1++;
          } else if (s2 > s1) {
            victoriesPlayer2++;
          }
        }
      }

      String winner = victoriesPlayer1 > victoriesPlayer2
          ? match.player1
          : victoriesPlayer2 > victoriesPlayer1
          ? match.player2
          : '';

      victories[match.player1] =
          (victories[match.player1] ?? 0) + (winner == match.player1 ? 1 : 0);
      victories[match.player2] =
          (victories[match.player2] ?? 0) + (winner == match.player2 ? 1 : 0);
    }

    final sortedEntries = victories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final ranking = sortedEntries
        .asMap()
        .map(
          (index, entry) => MapEntry(
        index + 1,
        "${entry.key} - ${entry.value} victoires",
      ),
    )
        .values
        .toList();

    return ranking;
  }

  // --- Liste des matchs de la poule sélectionnée ---

  Widget _buildMatchListSection(List<MatchTournament> matchList) {
    return _buildMatches(matchList);
  }

  Widget _buildMatches(List<MatchTournament> matchList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("poule_matches".tr()),
        ),
        const SizedBox(height: 8.0),
        ...matchList.map(
              (e) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("${e.player1} VS ${e.player2} : ${e.score}"),
          ),
        ),
      ],
    );
  }

  List<MatchTournament> getMatchListFromPoule(Tournament tournament) {
    final pouleList = tournament.pouleList;
    if (pouleList.isEmpty) return [];
    final poule =
        pouleList.where((element) => element.name == selectedPoule).first;
    return poule.matchList;
  }

  // --- Bouton de saisie des scores de poule ---

  Widget _buildMatchResultButton(
      BuildContext context, Tournament tournament) {
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

  // --- Dialog de saisie des scores de poule ---

  void showMatchResultDialog(
      BuildContext context,
      Tournament tournament,
      DatabaseReference tournamentRef,
      String player1,
      String player2,
      ) {
    final vm = context.read<DetailTournamentViewModel>();

    Poule currentPoule = tournament.pouleList
        .firstWhere((element) => element.name == selectedPoule);

    String selectedPlayer1 =
    player1.isNotEmpty ? player1 : currentPoule.playerList.first;
    String selectedPlayer2 =
    player2.isNotEmpty ? player2 : currentPoule.playerList.last;

    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('result_match_input'.tr()),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerDropdown(
                currentPoule.playerList,
                selectedPlayer1,
                    (value) {
                  if (value == null) return;
                  selectedPlayer1 = value;
                  Navigator.of(dialogContext).pop();
                  showMatchResultDialog(
                    context,
                    tournament,
                    tournamentRef,
                    value,
                    selectedPlayer2,
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildPlayerDropdown(
                currentPoule.playerList,
                selectedPlayer2,
                    (value) {
                  if (value == null) return;
                  selectedPlayer2 = value;
                  Navigator.of(dialogContext).pop();
                  showMatchResultDialog(
                    context,
                    tournament,
                    tournamentRef,
                    selectedPlayer1,
                    value,
                  );
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
                final selectedPouleRef = tournamentRef
                    .child(tournament.name)
                    .child('pouleList')
                    .child(selectedPoule);

                bool matchExists = await checkMatchExists(
                  selectedPlayer1,
                  selectedPlayer2,
                  selectedPouleRef,
                );

                if (matchExists) {
                  String message = tr(
                    'matchAlreadyPlayed',
                    args: [selectedPlayer1, selectedPlayer2],
                  );
                  bool? result = await showAskDialog(context, message);
                  if (result == true &&
                      isValidScoreFormat(scoreController.text)) {
                    final time = DateTime.now();
                    MatchTournament newMatch = MatchTournament(
                      player1: selectedPlayer1,
                      player2: selectedPlayer2,
                      score: scoreController.text,
                      date: "${time.day}/${time.month}/${time.year}",
                      location: tournament.location,
                    );
                    await updateScore(
                      vm,
                      selectedPouleRef,
                      newMatch,
                      context,
                      tournament,
                    );
                    if (context.mounted) Navigator.of(dialogContext).pop();
                  }
                } else {
                  if (isValidScoreFormat(scoreController.text)) {
                    final time = DateTime.now();
                    MatchTournament newMatch = MatchTournament(
                      player1: selectedPlayer1,
                      player2: selectedPlayer2,
                      score: scoreController.text,
                      date: "${time.day}/${time.month}/${time.year}",
                      location: tournament.location,
                    );
                    await updateScore(
                      vm,
                      selectedPouleRef,
                      newMatch,
                      context,
                      tournament,
                    );
                    if (context.mounted) Navigator.of(dialogContext).pop();
                  } else {
                    showErrorDialog(
                        context, 'score_format_incorrect'.tr());
                  }
                }
              },
              child: Text('valid'.tr()),
            ),
          ],
        );
      },
    );
  }

  bool isValidScoreFormat(String score) {
    RegExp regex = RegExp(r'^\d+-\d+(;\d+-\d+)*$');
    return regex.hasMatch(score);
  }

  Widget _buildPlayerDropdown(
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

  Future<void> updateScore(
      DetailTournamentViewModel vm,
      DatabaseReference selectedPouleRef,
      MatchTournament newMatch,
      BuildContext context,
      Tournament tournament,
      ) async {
    await vm.updateMatch(selectedPouleRef, newMatch);

    setState(() {
      tournament.updatePoule(
        selectedPoule,
        newMatch.player1,
        newMatch.player2,
        newMatch.score,
      );
    });

    if (isAllMatchPlayed(tournament)) {
      await showInfoDialog(context, "all_match_poule_played".tr());
      updateGraph(vm, tournament);
      widget.tabController.animateTo(1);
    }
  }

  bool isAllMatchPlayed(Tournament tournament) {
    for (var poule in tournament.pouleList) {
      for (var match in poule.matchList) {
        if (match.score.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  void updateGraph(DetailTournamentViewModel vm, Tournament tournament) {
    Map<String, List<String>> pouleRankings = {};

    for (var poule in tournament.pouleList) {
      var wins = calculateWins(poule.matchList, poule.playerList);
      pouleRankings[poule.name] = rankPlayers(wins);
    }

    tournament.finalMatchList.quarterFinalList =
        createQuarterFinalBracket(vm, pouleRankings);

    final tournamentRef =
    FirebaseDatabase.instance.ref().child("tournois");
    saveQuarterFinalsToFirebase(
      tournamentRef,
      tournament,
      tournament.finalMatchList.quarterFinalList,
    );

    setState(() {});
  }

  Map<String, int> calculateWins(
      List<MatchTournament> matches, List<String> players) {
    Map<String, int> wins = Map.fromIterable(players, value: (_) => 0);

    for (var match in matches) {
      if (match.score.isEmpty) continue;

      var scoreParts = match.score.split(';');
      int player1Wins = 0;
      int player2Wins = 0;

      for (var score in scoreParts) {
        var setScores = score.split('-');
        if (setScores.length == 2) {
          int player1Score = int.tryParse(setScores[0]) ?? 0;
          int player2Score = int.tryParse(setScores[1]) ?? 0;

          if (player1Score > player2Score) {
            player1Wins++;
          } else if (player2Score > player1Score) {
            player2Wins++;
          }
        }
      }

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

  List<MatchTournament> createQuarterFinalBracket(
      DetailTournamentViewModel vm,
      Map<String, List<String>> pouleRankings,
      ) {
    return [
      MatchTournament(
        player1: pouleRankings['A']![0],
        player2: pouleRankings['B']![1],
        score: '',
        date: vm.calculateDate("1/4"),
        location: vm.tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['C']![0],
        player2: pouleRankings['D']![1],
        score: '',
        date: vm.calculateDate("1/4"),
        location: vm.tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['B']![0],
        player2: pouleRankings['A']![1],
        score: '',
        date: vm.calculateDate("1/4"),
        location: vm.tournament.location,
      ),
      MatchTournament(
        player1: pouleRankings['D']![0],
        player2: pouleRankings['C']![1],
        score: '',
        date: vm.calculateDate("1/4"),
        location: vm.tournament.location,
      ),
    ];
  }

  Future<void> saveQuarterFinalsToFirebase(
      DatabaseReference tournamentRef,
      Tournament tournament,
      List<MatchTournament> quarterFinals,
      ) async {
    try {
      await tournamentRef.child(tournament.name).update({
        "quartFinal": quarterFinals.map((match) => match.toJson()).toList(),
      });
    } catch (e) {
      // ignore: avoid_print
      print("Erreur lors de l'enregistrement des quarts de finale : $e");
    }
  }

  Future<bool> checkMatchExists(
      String player1,
      String player2,
      DatabaseReference databaseReference,
      ) async {
    try {
      DataSnapshot snapshot =
          (await databaseReference.child('matchs').once()).snapshot;
      if (snapshot.value == null) return false;

      List<Object?> matches = snapshot.value as List<Object?>;

      for (var match in matches) {
        if (match is! Map) continue;
        Map currentMatch = match as Map<Object?, Object?>;

        if (currentMatch["score"] == "") continue;

        String matchKey1 =
            '${currentMatch['player1']}-${currentMatch['player2']}';
        String matchKey2 =
            '${currentMatch['player2']}-${currentMatch['player1']}';
        String keyToCheck = '$player1-$player2';

        if (matchKey1 == keyToCheck || matchKey2 == keyToCheck) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print("Erreur lors de la vérification du match: $e");
      return false;
    }
  }
}

// ======================================================================
//                          ONGLET ARBRE
// ======================================================================

class _BracketTab extends StatefulWidget {
  const _BracketTab({super.key});

  @override
  State<_BracketTab> createState() => _BracketTabState();
}

class _BracketTabState extends State<_BracketTab> {
  late BuchheimWalkerConfiguration builder;

  @override
  void initState() {
    super.initState();
    builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = 100
      ..levelSeparation = 150
      ..subtreeSeparation = 150
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetailTournamentViewModel>();
    final tournament = vm.tournament;
    final tournamentRef =
    FirebaseDatabase.instance.ref().child("tournois");

    return Column(
      children: [
        if(tournament.finalMatchList.finalMatch.score.isEmpty)
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
    );
  }

  // --- Dialog de saisie des scores sur l'arbre ---

  void showMatchArbreDialog(
      BuildContext context,
      Tournament tournament,
      DatabaseReference tournamentRef,
      String player1,
      String player2,
      ) {
    final vm = context.read<DetailTournamentViewModel>();

    List<String> playerList = <String>[];

    if (hasNotEmptyElements(tournament.finalMatchList.quarterFinalList)) {
      playerList = getPlayerList(tournament.finalMatchList.quarterFinalList);
    } else if (hasNotEmptyElements(tournament.finalMatchList.semiFinalist)) {
      playerList = getPlayerList(tournament.finalMatchList.semiFinalist);
    } else if (tournament.finalMatchList.finalMatch.score.isEmpty) {
      playerList = [
        tournament.finalMatchList.finalMatch.player1,
        tournament.finalMatchList.finalMatch.player2,
      ];
    }

    String selectedPlayer1 =
    player1.isNotEmpty ? player1 : playerList.first;
    String selectedPlayer2 = player2.isNotEmpty
        ? player2
        : retrievePlayer(selectedPlayer1, tournament.finalMatchList);

    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('result_match_input'.tr()),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerDropdown(
                playerList,
                selectedPlayer1,
                    (value) {
                  if (value == null) return;
                  selectedPlayer1 = value;
                  selectedPlayer2 =
                      retrievePlayer(selectedPlayer1, tournament.finalMatchList);
                  Navigator.of(dialogContext).pop();
                  showMatchArbreDialog(
                    context,
                    tournament,
                    tournamentRef,
                    selectedPlayer1,
                    selectedPlayer2,
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildPlayerDropdown(
                playerList,
                selectedPlayer2,
                    (value) {
                  if (value == null) return;
                  selectedPlayer2 = value;
                  selectedPlayer1 =
                      retrievePlayer(selectedPlayer2, tournament.finalMatchList);
                  Navigator.of(dialogContext).pop();
                  showMatchArbreDialog(
                    context,
                    tournament,
                    tournamentRef,
                    selectedPlayer1,
                    selectedPlayer2,
                  );
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
                if (isValidScoreFormat(scoreController.text)) {
                  MatchTournament newMatch = MatchTournament(
                    player1: selectedPlayer1,
                    player2: selectedPlayer2,
                    score: scoreController.text,
                    date:
                    "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                    location: tournament.location,
                  );
                  DatabaseReference endTournamentRef =
                  getTournamentRef(tournament, newMatch);
                  await updateScoreGraph(
                    vm,
                    endTournamentRef,
                    newMatch,
                    tournament,
                  );
                  if (context.mounted) Navigator.of(dialogContext).pop();
                } else {
                  showErrorDialog(context, 'score_format_incorrect'.tr());
                }
              },
              child: Text('valid'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateScoreGraph(
      DetailTournamentViewModel vm,
      DatabaseReference endTournamentRef,
      MatchTournament newMatch,
      Tournament tournament,
      ) async {
    await vm.updateMatchGraph(endTournamentRef, newMatch);

    setState(() {
      tournament.updateFinaleMatch(newMatch);
    });
  }

  // --- Helpers arbre ---

  bool isValidScoreFormat(String score) {
    RegExp regex = RegExp(r'^\d+-\d+(;\d+-\d+)*$');
    return regex.hasMatch(score);
  }

  Widget _buildPlayerDropdown(
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

  List<String> getPlayerList(List<MatchTournament> listMatch) {
    List<String> playerList = [];
    for (MatchTournament match in listMatch) {
      playerList.add(match.player1);
      playerList.add(match.player2);
    }
    return playerList;
  }

  bool hasNotEmptyElements(List<MatchTournament> list) {
    for (MatchTournament currentMatch in list) {
      if (currentMatch.score.isEmpty) return true;
    }
    return false;
  }

  DatabaseReference getTournamentRef(
      Tournament tournament,
      MatchTournament match,
      ) {
    final tournamentRef = FirebaseDatabase.instance
        .ref()
        .child("tournois")
        .child(tournament.name);
    final end = tournament.finalMatchList;

    final quarterIndex = tournament.getIndex(end.quarterFinalList, match);
    if (quarterIndex != -1) {
      return tournamentRef.child("quartFinal").child(quarterIndex.toString());
    }

    final semiIndex = tournament.getIndex(end.semiFinalist, match);
    if (semiIndex != -1) {
      return tournamentRef.child("semiFinal").child(semiIndex.toString());
    }

    // Sinon on considère que c'est la finale
    return tournamentRef.child('finalMatch');
  }

  String retrievePlayer(String selectedPlayer, EndTournament tournament) {
    String player = "";
    if (hasNotEmptyElements(tournament.quarterFinalList)) {
      for (MatchTournament match in tournament.quarterFinalList) {
        if (match.player1 == selectedPlayer) {
          player = match.player2;
          continue;
        } else if (match.player2 == selectedPlayer) {
          player = match.player1;
          continue;
        }
      }
    } else if (hasNotEmptyElements(tournament.semiFinalist)) {
      for (MatchTournament match in tournament.semiFinalist) {
        if (match.player1 == selectedPlayer) {
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

  // --- GraphView ---

  Widget rectangleWidget(String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.blue[100]!, spreadRadius: 1),
        ],
      ),
      child: Text(label),
    );
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
    getTournamentNode(3, endTournament, 0, TournamentPhase.SEMI_FINAL, true);
    final TournamentNode semiPlayer2Node =
    getTournamentNode(4, endTournament, 0, TournamentPhase.SEMI_FINAL, false);
    final TournamentNode semiPlayer3Node =
    getTournamentNode(5, endTournament, 1, TournamentPhase.SEMI_FINAL, true);
    final TournamentNode semiPlayer4Node =
    getTournamentNode(6, endTournament, 1, TournamentPhase.SEMI_FINAL, false);

    final TournamentNode quarterPlayer1Node =
    getTournamentNode(7, endTournament, 0, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer2Node =
    getTournamentNode(8, endTournament, 0, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer3Node =
    getTournamentNode(9, endTournament, 1, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer4Node =
    getTournamentNode(10, endTournament, 1, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer5Node =
    getTournamentNode(11, endTournament, 2, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer6Node =
    getTournamentNode(12, endTournament, 2, TournamentPhase.QUARTER_FINAL, false);
    final TournamentNode quarterPlayer7Node =
    getTournamentNode(13, endTournament, 3, TournamentPhase.QUARTER_FINAL, true);
    final TournamentNode quarterPlayer8Node =
    getTournamentNode(14, endTournament, 3, TournamentPhase.QUARTER_FINAL, false);

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

  TournamentNode getTournamentNode(
      int id,
      EndTournament endTournament,
      int index,
      TournamentPhase phase,
      bool player1,
      ) {
    switch (phase) {
      case TournamentPhase.FINAL:
        return _buildNodeFromMatch(endTournament.finalMatch, id, player1);
      case TournamentPhase.SMALL_FINAL:
        return _buildNodeFromMatch(endTournament.smallFinalMatch, id, player1);
      case TournamentPhase.SEMI_FINAL:
        if (index >= 0 && index < endTournament.semiFinalist.length) {
          final m = endTournament.semiFinalist[index];
          return _buildNodeFromMatch(m, id, player1);
        }
        throw RangeError('index demi-finale hors bornes: $index');
      case TournamentPhase.QUARTER_FINAL:
        if (index >= 0 && index < endTournament.quarterFinalList.length) {
          final m = endTournament.quarterFinalList[index];
          return _buildNodeFromMatch(m, id, player1);
        }
        throw RangeError('index quart de finale hors bornes: $index');
      case TournamentPhase.GROUP:
        throw StateError(
            'La phase GROUP n\'a pas de TournamentNode dans EndTournament');
    }
  }

  TournamentNode _buildNodeFromMatch(
      MatchTournament m, int id, bool isPlayer1) {
    final name = isPlayer1 ? m.player1 : m.player2;
    return TournamentNode(id, name);
  }
}
