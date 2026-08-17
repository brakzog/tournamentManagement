import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tournament_management/graphView/GraphView.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/poule.dart';
import 'package:tournament_management/models/tournament.dart';
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
          if (_canShowCancelButton(state))
            IconButton(
              icon: const Icon(Icons.event_busy),
              tooltip: 'cancel_tournament_action'.tr(),
              onPressed: () async {
                final t = state.tournament;
                if (t == null) return;

                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('cancel_tournament_title'.tr()),
                    content: Text('cancel_tournament_confirm'.tr()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('cancel'.tr()),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('cancel_tournament_confirm_button'.tr()),
                      ),
                    ],
                  ),
                );

                if (ok == true) {
                  vm.onIntent(const DetailTournamentIntentCancelConfirmed());
                }
              },
            ),
          if (_canShowDeleteButton(state))
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final t = state.tournament;
                if (t == null) return;

                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('delete_tournament_title'.tr()),
                    content: Text('delete_tournament_confirm'.tr()),

                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('cancel'.tr()),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('delete'.tr()),
                      ),
                    ],
                  ),
                );

                if (ok == true) {
                  vm.onIntent(const DetailTournamentIntentDeleteConfirmed());
                }
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
          if (state.tournament?.isCancelled == true)
            Container(
              width: double.infinity,
              color: Colors.grey.withOpacity(0.2),
              padding: const EdgeInsets.all(8),
              child: Text(
                'tournament_cancelled_banner'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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

/// Le créateur peut annuler son tournoi tant qu'il n'est pas déjà terminé
/// (finale jouée) ni déjà annulé. Mutuellement exclusif avec le bouton de
/// suppression par construction (celui-ci exige au contraire une finale
/// jouée).
bool _canShowCancelButton(DetailTournamentState state) {
  final tournament = state.tournament;
  if (tournament == null) return false;
  if (tournament.isCancelled) return false;

  final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
  if (currentUserEmail == null) return false;

  final isCreator = tournament.createdBy == currentUserEmail;
  final notFinished = tournament.finalMatchList.finalMatch.score.isEmpty;

  return isCreator && notFinished;
}

// ======================================================================
//                          WIDGETS PARTAGÉS
// ======================================================================

/// Sélecteur de joueur générique, partagé entre les dialogues de poule et
/// d'arbre (évite la duplication qui existait entre les deux onglets).
Widget _buildPlayerDropdown(
    List<String> playerList,
    String selectedPlayer,
    ValueChanged<String?> onChanged,
    ) {
  return DropdownButton<String>(
    value: selectedPlayer,
    hint: Text('player_selection'.tr()),
    onChanged: onChanged,
    items: playerList.map<DropdownMenuItem<String>>((String player) {
      return DropdownMenuItem<String>(
        value: player,
        child: Text(player),
      );
    }).toList(),
  );
}

/// Nœud rectangulaire de l'arbre : vert si le match est joué, bordure
/// bleue s'il est cliquable (score encore vide).
Widget _rectangleWidget(
    String label, {
      bool played = false,
      bool playable = false,
    }) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: played ? Colors.green.withOpacity(0.15) : null,
      borderRadius: BorderRadius.circular(4),
      border: playable ? Border.all(color: Colors.blue, width: 2) : null,
      boxShadow: [
        BoxShadow(color: Colors.blue[100]!, spreadRadius: 1),
      ],
    ),
    child: Text(label),
  );
}

// ======================================================================
//                          ONGLET POULES
// ======================================================================

class _PoolPhaseTab extends StatelessWidget {
  final TabController tabController;

  const _PoolPhaseTab({
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetailTournamentViewModel>();
    final tournament = vm.tournament;
    final selectedPoule = vm.state.selectedPoule ?? "A";

    final bool isEmpty = tournament.pouleList.isEmpty;
    final List<MatchTournament> matchList =
        vm.getMatchListFromPoule(selectedPoule);

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
          if (shouldDisplayPouleSelector)
            _buildPouleSelector(vm, tournament, selectedPoule),
          if (shouldDisplayPouleSelector)
            _buildRankingSection(tournament, selectedPoule),
          const SizedBox(height: 16.0),
          _buildMatchListSection(matchList),
          const SizedBox(height: 16.0),
          if (shouldDisplayMatchResultButton)
            _buildMatchResultButton(context, vm, tournament, selectedPoule),
        ],
      ),
    );
  }

  // --- Bouton de démarrage / génération des poules ---

  Widget _buildStartTournamentButton(DetailTournamentViewModel vm) {
    return ElevatedButton(
      onPressed: () async {
        await vm.generatePoolsAndUpdateTournament();
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

  Widget _buildPouleSelector(
      DetailTournamentViewModel vm,
      Tournament tournament,
      String selectedPoule,
      ) {
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
              vm.onIntent(SelectPouleIntent(value));
            }
          },
        ),
      ],
    );
  }

  // --- Classement de la poule sélectionnée ---

  Widget _buildRankingSection(Tournament tournament, String selectedPoule) {
    final matches =
        tournament.pouleList.where((element) => element.name == selectedPoule);
    if (matches.isEmpty) return const SizedBox.shrink();
    return _buildRanking(matches.first);
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

  // --- Bouton de saisie des scores de poule ---

  Widget _buildMatchResultButton(
      BuildContext context,
      DetailTournamentViewModel vm,
      Tournament tournament,
      String selectedPoule,
      ) {
    final tournamentRef = FirebaseDatabase.instance.ref().child("tournois");
    return ElevatedButton(
      child: Text("result_match_input".tr()),
      onPressed: () => _showMatchResultDialog(
        context,
        vm,
        tournament,
        tournamentRef,
        selectedPoule,
        "",
        "",
      ),
    );
  }

  // --- Dialog de saisie des scores de poule ---

  void _showMatchResultDialog(
      BuildContext context,
      DetailTournamentViewModel vm,
      Tournament tournament,
      DatabaseReference tournamentRef,
      String selectedPoule,
      String player1,
      String player2,
      ) {
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
                  _showMatchResultDialog(
                    context,
                    vm,
                    tournament,
                    tournamentRef,
                    selectedPoule,
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
                  _showMatchResultDialog(
                    context,
                    vm,
                    tournament,
                    tournamentRef,
                    selectedPoule,
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
                    .child(tournament.id)
                    .child('pouleList')
                    .child(selectedPoule);

                bool matchExists = await vm.checkMatchExists(
                  selectedPlayer1,
                  selectedPlayer2,
                  selectedPouleRef,
                );

                Future<void> submitScore() async {
                  final time = DateTime.now();
                  MatchTournament newMatch = MatchTournament(
                    player1: selectedPlayer1,
                    player2: selectedPlayer2,
                    score: scoreController.text,
                    date: "${time.day}/${time.month}/${time.year}",
                    location: tournament.location,
                  );

                  final allPlayed = await vm.submitPouleMatchScore(
                    selectedPoule,
                    selectedPouleRef,
                    newMatch,
                  );

                  if (allPlayed) {
                    if (context.mounted) {
                      await showInfoDialog(
                          context, "all_match_poule_played".tr());
                    }
                    await vm.generateQuarterFinalsFromPoules();
                    tabController.animateTo(1);
                  }

                  if (context.mounted) Navigator.of(dialogContext).pop();
                }

                if (matchExists) {
                  String message = tr(
                    'matchAlreadyPlayed',
                    args: [selectedPlayer1, selectedPlayer2],
                  );
                  bool? result = await showAskDialog(context, message);
                  if (result == true &&
                      isValidScoreFormat(scoreController.text)) {
                    await submitScore();
                  }
                } else {
                  if (isValidScoreFormat(scoreController.text)) {
                    await submitScore();
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

    if (!vm.isBracketReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "bracket_not_ready".tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        if (tournament.finalMatchList.finalMatch.score.isEmpty)
          ElevatedButton(
            child: Text("result_match_input".tr()),
              onPressed: () => _showMatchArbreDialog(
                context,
                vm,
                tournament,
                "",
                "",
              ),
          ),
        if (tournament.finalMatchList.smallFinalMatch.player1.isNotEmpty &&
            tournament.finalMatchList.smallFinalMatch.score.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton(
              child: Text("small_final_result_input".tr()),
              onPressed: () => _showSmallFinalDialog(
                context,
                vm,
                tournament,
                "",
                "",
              ),
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
                builder: (node) => _buildTappableNode(
                  context,
                  vm,
                  tournament,
                  node as TournamentNode,
                ),
                graph: vm.createTournamentTree(),
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

  /// Rend un nœud de l'arbre. Si ce nœud représente un match dont le score
  /// n'a pas encore été saisi, il devient cliquable et ouvre directement le
  /// dialogue de saisie pré-rempli avec les deux joueurs de ce match.
  Widget _buildTappableNode(
      BuildContext context,
      DetailTournamentViewModel vm,
      Tournament tournament,
      TournamentNode node,
      ) {
    final match = node.match;
    final bool played = match != null && match.score.isNotEmpty;
    final bool playable = match != null && match.score.isEmpty;

    final Widget content = _rectangleWidget(
      node.label,
      played: played,
      playable: playable,
    );

    if (!playable) {
      return content;
    }

    return InkWell(
      onTap: () => _showMatchArbreDialog(
        context,
        vm,
        tournament,
        match.player1,
        match.player2,
      ),
      child: content,
    );
  }

  // --- Dialog de saisie des scores sur l'arbre ---

  void _showMatchArbreDialog(
      BuildContext context,
      DetailTournamentViewModel vm,
      Tournament tournament,
      String player1,
      String player2,
      ) {
    List<String> playerList = <String>[];

    if (vm.hasNotEmptyElements(tournament.finalMatchList.quarterFinalList)) {
      playerList = vm.getPlayerList(tournament.finalMatchList.quarterFinalList);
    } else if (vm.hasNotEmptyElements(tournament.finalMatchList.semiFinalist)) {
      playerList = vm.getPlayerList(tournament.finalMatchList.semiFinalist);
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
        : vm.retrievePlayer(selectedPlayer1);

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
                  selectedPlayer2 = vm.retrievePlayer(selectedPlayer1);
                  Navigator.of(dialogContext).pop();
                  _showMatchArbreDialog(
                    context,
                    vm,
                    tournament,
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
                  selectedPlayer1 = vm.retrievePlayer(selectedPlayer2);
                  Navigator.of(dialogContext).pop();
                  _showMatchArbreDialog(
                    context,
                    vm,
                    tournament,
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
                  await vm.submitBracketMatchScore(newMatch);
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

  // --- Dialog de saisie du score de la petite finale (3e place) ---
  //
  // Contrairement à _showMatchArbreDialog, les deux joueurs sont toujours
  // connus dès la génération (perdants des demies) : pas de cascade à faire
  // entre plusieurs listes de matchs, juste un swap possible via dropdown.
  void _showSmallFinalDialog(
      BuildContext context,
      DetailTournamentViewModel vm,
      Tournament tournament,
      String player1,
      String player2,
      ) {
    final smallFinal = tournament.finalMatchList.smallFinalMatch;

    final List<String> playerList = [smallFinal.player1, smallFinal.player2];

    String selectedPlayer1 = player1.isNotEmpty ? player1 : playerList.first;
    String selectedPlayer2 = player2.isNotEmpty ? player2 : playerList.last;

    TextEditingController scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('small_final_result_input'.tr()),
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
                  Navigator.of(dialogContext).pop();
                  _showSmallFinalDialog(
                    context,
                    vm,
                    tournament,
                    value,
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
                  Navigator.of(dialogContext).pop();
                  _showSmallFinalDialog(
                    context,
                    vm,
                    tournament,
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
                if (isValidScoreFormat(scoreController.text)) {
                  final time = DateTime.now();
                  MatchTournament newMatch = MatchTournament(
                    player1: selectedPlayer1,
                    player2: selectedPlayer2,
                    score: scoreController.text,
                    date: "${time.day}/${time.month}/${time.year}",
                    location: tournament.location,
                  );
                  await vm.submitBracketMatchScore(newMatch);
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
}
