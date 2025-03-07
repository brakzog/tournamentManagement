// Vue principale
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_presenter.dart';
import 'package:tournament_management/pages/create_tournament/create_tournament_viewmodel.dart';
import 'package:tournament_management/widgets/address_autocomplete.dart';

class CreateTournamentPage extends StatelessWidget {
  const CreateTournamentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<CreateTournamentViewModel>(context);
    final presenter = CreateTournamentPresenter(viewModel);

    return Scaffold(
      appBar: AppBar(
        title: Text("create_tournament_title".tr(), style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
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
              AdresseAutocompleteField(controller: viewModel.locationController),
              const SizedBox(height: 16.0),
              _buildGuestList(viewModel, presenter),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () => presenter.addGuest(context),
                child: Text("add_guest".tr()),
              ),
              const SizedBox(height: 16.0),
              Text("tournament_date_definition".tr()+ " : \n${viewModel.tournamentDate} -> ${viewModel.endTournamentDate}"),
              ElevatedButton(
                onPressed: () => presenter.pickTournamentDate(context),
                child: Text("tournament_begin_date".tr()),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () => presenter.submitTournament(context),
                child: const Text("Créer le tournoi"),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildGuestList(CreateTournamentViewModel viewModel, CreateTournamentPresenter presenter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("participant_list".tr()),
        const SizedBox(height: 8.0),
        Wrap(
          children: viewModel.guestList.map((guest) {
            return Chip(
              label: Text(guest),
              deleteIcon: const Icon(Icons.cancel),
              onDeleted: () => presenter.removeGuest(guest),
            );
          }).toList(),
        ),
      ],
    );
  }
}



class AnimatedCreateTournamentPageRoute extends PageRouteBuilder {
  final Widget page;

  AnimatedCreateTournamentPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
