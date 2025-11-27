import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tournament_management/models/participation_model.dart';

import 'participation_viewmodel.dart';

class ParticipationView extends StatefulWidget {
  const ParticipationView({super.key});

  @override
  State<ParticipationView> createState() => _ParticipationViewState();
}

class _ParticipationViewState extends State<ParticipationView> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        final viewModel = context.read<ParticipationViewModel>();
        viewModel.onIntent(const LoadParticipationIntent());
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ParticipationViewModel>();
    final state = viewModel.state;

    return Column(
      children: [
        // --- Mon calendrier ---
        ExpansionTile(
          title: Text("my_calendar".tr()),
          children: [
            if (state.isLoadingUpcoming)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorUpcoming != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'error_fetching'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (state.upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Center(
                    child: Text('no_calendar_data'.tr()),
                  ),
                )
              else
                _buildParticipationList(state.upcoming),
          ],
        ),

        // --- Mes résultats ---
        ExpansionTile(
          title: Text("my_result".tr()),
          children: [
            if (state.isLoadingResults)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorResults != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'error_fetching'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (state.results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Center(
                    child: Text('no_result'.tr()),
                  ),
                )
              else
                _buildParticipationList(state.results),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipationList(List<ParticipationModel> list) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${"opponent".tr()}: ${item.opposant}"),
                Text("${"location".tr()}: ${item.location}"),
                Text("${"date".tr()}: ${item.date}"),
                if (item.score.isNotEmpty)
                  Text("${"score".tr()}: ${item.score}"),
              ],
            ),
          ),
        );
      },
    );
  }
}
