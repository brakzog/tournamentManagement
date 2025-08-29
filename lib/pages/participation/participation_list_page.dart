import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:tournament_management/models/participation_model.dart';
import 'package:tournament_management/pages/participation/participation_viewmodel.dart';
import 'package:tournament_management/pages/participation/participation_presenter.dart';


class ParticipationListPage extends StatefulWidget {
  final bool played; // false = à jouer, true = joués
  const ParticipationListPage({super.key, required this.played});

  @override
  State<ParticipationListPage> createState() => _ParticipationListPageState();
}

class _ParticipationListPageState extends State<ParticipationListPage> {
  late ParticipationPresenter _presenter;
  late Future<List<ParticipationModel>> _future;

  @override
  void initState() {
    super.initState();
    final vm = context.read<ParticipationViewModel>();
    _presenter = ParticipationPresenter(vm);
    _future = _presenter.load(played: widget.played);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _presenter.load(played: widget.played);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.played ? 'my_results'.tr() : 'my_calendar'.tr()),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ParticipationModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('error_fetching'.tr())),
                ],
              );
            }

            final items = _presenter.sorted(
              snap.data ?? const <ParticipationModel>[],
              played: widget.played,
            );

            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.played ? 'no_result'.tr() : 'no_calendar_data'.tr(),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(), // pour pouvoir tirer même si peu d’items
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = items[i];
                final displayDate = m.date.contains('→ ')
                    ? m.date.split('→ ').first
                    : m.date;
                final subtitle = '${displayDate} • ${m.location}';

                return ListTile(
                  title: Text(
                    m.score.isNotEmpty ? '${m.opposant} • ${m.score}' : m.opposant,
                  ),
                  subtitle: Text(subtitle),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
