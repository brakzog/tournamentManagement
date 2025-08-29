import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'participation_presenter.dart';
import 'participation_viewmodel.dart';

class ParticipationView extends StatelessWidget {
  const ParticipationView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParticipationViewModel>();
    final presenter = ParticipationPresenter(vm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          title: Text("my_calendar").tr(),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            presenter.buildMyCalendar(context),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => presenter.openFullList(context, played: false),
                child: Text('see_all').tr(),
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text("my_result").tr(),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            presenter.buildMyResult(context),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => presenter.openFullList(context, played: true),
                child: Text('see_all').tr(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
