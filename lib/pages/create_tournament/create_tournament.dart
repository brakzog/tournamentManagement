import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_viewmodel.dart';
import 'package:tournament_management/widgets/address_autocomplete.dart';

class CreateTournamentPage extends StatefulWidget {
  const CreateTournamentPage({super.key});

  @override
  State<CreateTournamentPage> createState() => _CreateTournamentPageState();
}

class _CreateTournamentPageState extends State<CreateTournamentPage> {
  final complementFocusNode = FocusNode();
  final TextEditingController _guestInputController = TextEditingController();

  @override
  void dispose() {
    complementFocusNode.dispose();
    _guestInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<CreateTournamentViewModel>(context);
    final state = viewModel.state;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "create_tournament_title".tr(),
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTextField(
                controller: viewModel.tournamentNameController,
                label: "tournament_name".tr(),
              ),
              const SizedBox(height: 16.0),
              _buildTextField(
                controller: viewModel.eventTypeController,
                label: "tournament_type".tr(),
              ),
              const SizedBox(height: 16.0),
              AdresseAutocompleteField(
                controller: viewModel.locationController,
                nextFocus: complementFocusNode,
              ),
              const SizedBox(height: 16.0),

              // Liste des participants
              _buildGuestList(viewModel, state),

              const SizedBox(height: 8.0),

              // Saisie des invités (via un TextField + bouton)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guestInputController,
                      decoration: InputDecoration(
                        labelText: "add_guest".tr(),
                        hintText: "guest_input_hint".tr(),
                      ),
                      onFieldSubmitted: (_) => _onAddGuest(viewModel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _onAddGuest(viewModel),
                    child: Text("add_guest".tr()),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // Dates
              Text(
                "${"tournament_date_definition".tr()} : \n"
                    "${state.tournamentDate} -> ${state.endTournamentDate}",
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () => viewModel.onIntent(
                  PickTournamentDateIntent(context),
                ),
                child: Text("tournament_begin_date".tr()),
              ),

              const SizedBox(height: 16.0),

              // Erreur éventuelle
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Bouton de création
              ElevatedButton(
                onPressed: state.isSaving
                    ? null
                    : () => viewModel.onIntent(
                  SubmitTournamentIntent(context),
                ),
                child: state.isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Créer le tournoi"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAddGuest(CreateTournamentViewModel viewModel) {
    final text = _guestInputController.text.trim();
    if (text.isEmpty) return;
    viewModel.onIntent(AddGuestIntent(text));
    _guestInputController.clear();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildGuestList(
      CreateTournamentViewModel viewModel,
      CreateTournamentState state,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("participant_list".tr()),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: state.guests.map((guest) {
            return Chip(
              label: Text(guest),
              deleteIcon: const Icon(Icons.cancel),
              onDeleted: () =>
                  viewModel.onIntent(RemoveGuestIntent(guest)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Animation existante conservée
class AnimatedCreateTournamentPageRoute extends PageRouteBuilder {
  final Widget page;

  AnimatedCreateTournamentPageRoute({required this.page})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;

      var tween =
      Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}
