import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/utils.dart';

/// --- STATE --- ///
class CreateTournamentState {
  final String tournamentDate;       // début
  final String endTournamentDate;    // fin
  final List<String> guests;
  final bool isSaving;
  final String? errorMessage;

  const CreateTournamentState({
    this.tournamentDate = "",
    this.endTournamentDate = "",
    this.guests = const [],
    this.isSaving = false,
    this.errorMessage,
  });

  CreateTournamentState copyWith({
    String? tournamentDate,
    String? endTournamentDate,
    List<String>? guests,
    bool? isSaving,
    String? errorMessage,
  }) {
    return CreateTournamentState(
      tournamentDate: tournamentDate ?? this.tournamentDate,
      endTournamentDate: endTournamentDate ?? this.endTournamentDate,
      guests: guests ?? this.guests,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
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

  CreateTournamentState _state = const CreateTournamentState();
  CreateTournamentState get state => _state;

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

    _setState(
      _state.copyWith(
        isSaving: true,
        errorMessage: null,
      ),
    );

    try {
      final dbRef = FirebaseDatabase.instance.ref().child('tournois');

      await dbRef.child(tournamentName).set({
        'createdBy': createdBy,
        'sportEvent': eventType,
        'location': location,
        'participants': guests,
        'tournamentDate': {
          'beginingDate': startDate,
          'endDate': endDate,
        },
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
    _setState(
      const CreateTournamentState(), // remet dates + guests + erreurs à zéro
    );
  }
}
