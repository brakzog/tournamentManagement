import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/bracket_format.dart';
import 'package:tournament_management/models/match_rules.dart';
import 'package:tournament_management/models/tournament_rules.dart';
import 'package:tournament_management/repositories/tournament_repository.dart';
import 'package:tournament_management/utils.dart';

/// --- STATE --- ///
class CreateTournamentState {
  final String tournamentDate;       // début
  final String endTournamentDate;    // fin
  final List<String> guests;
  final bool isSaving;
  final String? errorMessage;

  // Règles de match (poules + tours avant demies)
  final bool winByTwo;

  // Dérogation optionnelle pour demies / finale / petite finale
  final bool useFinalPhaseRules;
  final bool finalWinByTwo;

  // Format du tournoi
  final BracketFormat bracketFormat;
  final bool useRepechage;

  const CreateTournamentState({
    this.tournamentDate = "",
    this.endTournamentDate = "",
    this.guests = const [],
    this.isSaving = false,
    this.errorMessage,
    this.winByTwo = true,
    this.useFinalPhaseRules = false,
    this.finalWinByTwo = true,
    this.bracketFormat = BracketFormat.poules,
    this.useRepechage = false,
  });

  CreateTournamentState copyWith({
    String? tournamentDate,
    String? endTournamentDate,
    List<String>? guests,
    bool? isSaving,
    String? errorMessage,
    bool? winByTwo,
    bool? useFinalPhaseRules,
    bool? finalWinByTwo,
    BracketFormat? bracketFormat,
    bool? useRepechage,
  }) {
    return CreateTournamentState(
      tournamentDate: tournamentDate ?? this.tournamentDate,
      endTournamentDate: endTournamentDate ?? this.endTournamentDate,
      guests: guests ?? this.guests,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      winByTwo: winByTwo ?? this.winByTwo,
      useFinalPhaseRules: useFinalPhaseRules ?? this.useFinalPhaseRules,
      finalWinByTwo: finalWinByTwo ?? this.finalWinByTwo,
      bracketFormat: bracketFormat ?? this.bracketFormat,
      useRepechage: useRepechage ?? this.useRepechage,
    );
  }
}

/// --- INTENTS --- ///
abstract class CreateTournamentIntent {
  const CreateTournamentIntent();
}

class AddGuestIntent extends CreateTournamentIntent {
  final String input;
  const AddGuestIntent(this.input);
}

class RemoveGuestIntent extends CreateTournamentIntent {
  final String guest;
  const RemoveGuestIntent(this.guest);
}

class PickTournamentDateIntent extends CreateTournamentIntent {
  final BuildContext context;
  const PickTournamentDateIntent(this.context);
}

class ToggleWinByTwoIntent extends CreateTournamentIntent {
  const ToggleWinByTwoIntent();
}

class ToggleUseFinalPhaseRulesIntent extends CreateTournamentIntent {
  const ToggleUseFinalPhaseRulesIntent();
}

class ToggleFinalWinByTwoIntent extends CreateTournamentIntent {
  const ToggleFinalWinByTwoIntent();
}

class SelectBracketFormatIntent extends CreateTournamentIntent {
  final BracketFormat format;
  const SelectBracketFormatIntent(this.format);
}

class ToggleUseRepechageIntent extends CreateTournamentIntent {
  const ToggleUseRepechageIntent();
}

class SubmitTournamentIntent extends CreateTournamentIntent {
  final BuildContext context;
  const SubmitTournamentIntent(this.context);
}

/// --- VIEWMODEL --- ///
class CreateTournamentViewModel extends ChangeNotifier {
  final TextEditingController tournamentNameController =
  TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController eventTypeController = TextEditingController();

  // Règles de match (poules + tours avant demies)
  final TextEditingController pointsPerSetController =
  TextEditingController(text: '6');
  final TextEditingController setsToWinController =
  TextEditingController(text: '1');

  // Dérogation optionnelle pour demies / finale / petite finale
  final TextEditingController finalPointsPerSetController =
  TextEditingController(text: '6');
  final TextEditingController finalSetsToWinController =
  TextEditingController(text: '2');

  final TournamentRepository _repository;

  CreateTournamentState _state = const CreateTournamentState();
  CreateTournamentState get state => _state;

  CreateTournamentViewModel({TournamentRepository? repository})
      : _repository = repository ?? TournamentRepository();

  void _setState(CreateTournamentState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> onIntent(CreateTournamentIntent intent) async {
    if (intent is AddGuestIntent) {
      _handleAddGuest(intent.input);
    } else if (intent is RemoveGuestIntent) {
      _handleRemoveGuest(intent.guest);
    } else if (intent is PickTournamentDateIntent) {
      await _handlePickTournamentDate(intent.context);
    } else if (intent is ToggleWinByTwoIntent) {
      _setState(_state.copyWith(winByTwo: !_state.winByTwo));
    } else if (intent is ToggleUseFinalPhaseRulesIntent) {
      _setState(_state.copyWith(useFinalPhaseRules: !_state.useFinalPhaseRules));
    } else if (intent is ToggleFinalWinByTwoIntent) {
      _setState(_state.copyWith(finalWinByTwo: !_state.finalWinByTwo));
    } else if (intent is SelectBracketFormatIntent) {
      _setState(_state.copyWith(bracketFormat: intent.format));
    } else if (intent is ToggleUseRepechageIntent) {
      _setState(_state.copyWith(useRepechage: !_state.useRepechage));
    } else if (intent is SubmitTournamentIntent) {
      await _handleSubmit(intent.context);
    }
  }

  // --- Guests ---

  void _handleAddGuest(String rawInput) {
    final current = List<String>.from(_state.guests);

    final parts = rawInput
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    bool changed = false;
    for (final g in parts) {
      if (!current.contains(g)) {
        current.add(g);
        changed = true;
      }
    }

    if (changed) {
      _setState(
        _state.copyWith(
          guests: current,
          errorMessage: null,
        ),
      );
    }
  }

  void _handleRemoveGuest(String guest) {
    final updated = List<String>.from(_state.guests)..remove(guest);
    _setState(
      _state.copyWith(
        guests: updated,
        errorMessage: null,
      ),
    );
  }

  // --- Dates ---

  Future<void> _handlePickTournamentDate(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: "tournament_date_definition".tr(),
    );

    if (range != null) {
      final df = DateFormat("dd/MM/yyyy");
      final start = df.format(range.start);
      final end = df.format(range.end);

      _setState(
        _state.copyWith(
          tournamentDate: start,
          endTournamentDate: end,
          errorMessage: null,
        ),
      );
    }
  }

  // --- Règles de match ---

  /// Construit les [TournamentRules] à partir des champs saisis.
  /// Renvoie null si une valeur est invalide (message d'erreur alors
  /// disponible via [lastRulesErrorKey]).
  String? lastRulesErrorKey;

  TournamentRules? _buildRules() {
    lastRulesErrorKey = null;

    final pointsPerSet = int.tryParse(pointsPerSetController.text.trim());
    final setsToWin = int.tryParse(setsToWinController.text.trim());

    if (pointsPerSet == null || pointsPerSet < 1) {
      lastRulesErrorKey = 'invalid_points_per_set';
      return null;
    }
    if (setsToWin == null || setsToWin < 1) {
      lastRulesErrorKey = 'invalid_sets_to_win';
      return null;
    }

    final defaultRules = MatchRules(
      pointsPerSet: pointsPerSet,
      winByTwo: _state.winByTwo,
      setsToWin: setsToWin,
    );

    if (!_state.useFinalPhaseRules) {
      return TournamentRules(defaultRules: defaultRules);
    }

    final finalPointsPerSet =
    int.tryParse(finalPointsPerSetController.text.trim());
    final finalSetsToWin = int.tryParse(finalSetsToWinController.text.trim());

    if (finalPointsPerSet == null || finalPointsPerSet < 1) {
      lastRulesErrorKey = 'invalid_points_per_set';
      return null;
    }
    if (finalSetsToWin == null || finalSetsToWin < 1) {
      lastRulesErrorKey = 'invalid_sets_to_win';
      return null;
    }

    return TournamentRules(
      defaultRules: defaultRules,
      finalPhaseRules: MatchRules(
        pointsPerSet: finalPointsPerSet,
        winByTwo: _state.finalWinByTwo,
        setsToWin: finalSetsToWin,
      ),
    );
  }

  // --- Soumission ---

  Future<void> _handleSubmit(BuildContext context) async {
    final tournamentName = tournamentNameController.text.trim();
    final location = locationController.text.trim();
    final eventType = eventTypeController.text.trim();
    final startDate = _state.tournamentDate;
    final endDate = _state.endTournamentDate;
    final guests = _state.guests;

    // should always be not null as the user is already connected from here
    final createdBy = FirebaseAuth.instance.currentUser?.email ?? "";

    if (tournamentName.isEmpty || location.isEmpty || startDate.isEmpty) {
      showErrorDialog(context, "missing_field".tr());
      return;
    }

    if (guests.length < 8) {
      // On met un message clair en dur, pour éviter le trou de traduction
      showErrorDialog(context, "not_enough_people".tr());
      return;
    }

    final rules = _buildRules();
    if (rules == null) {
      showErrorDialog(context, lastRulesErrorKey!.tr());
      return;
    }

    _setState(
      _state.copyWith(
        isSaving: true,
        errorMessage: null,
      ),
    );

    try {
      await _repository.createTournament({
        'name': tournamentName,
        'createdBy': createdBy,
        'sportEvent': eventType,
        'location': location,
        'participants': guests,
        'tournamentDate': {
          'beginingDate': startDate,
          'endDate': endDate,
        },
        'rules': rules.toJson(),
        'bracketFormat': _state.bracketFormat.key,
        'useRepechage': _state.useRepechage,
      });

      if (kDebugMode) {
        print("Tournoi enregistré avec succès");
      }

      resetFields();
      showDialogTournament(context);
    } catch (e, st) {
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement du tournoi : $e");
        print(st);
      }
      showErrorDialog(
        context,
        "Erreur lors de l'enregistrement du tournoi : $e",
      );
      _setState(
        _state.copyWith(
          errorMessage: "Erreur lors de l'enregistrement du tournoi : $e",
        ),
      );
    } finally {
      _setState(
        _state.copyWith(isSaving: false),
      );
    }
  }

  // --- Reset ---

  void resetFields() {
    tournamentNameController.text = "";
    locationController.text = "";
    eventTypeController.text = "";
    pointsPerSetController.text = "6";
    setsToWinController.text = "1";
    finalPointsPerSetController.text = "6";
    finalSetsToWinController.text = "2";
    _setState(
      const CreateTournamentState(), // remet dates + guests + erreurs à zéro
    );
  }
}
