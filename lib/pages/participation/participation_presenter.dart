import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tournament_management/models/participation_model.dart';
import 'participation_viewmodel.dart';
import 'package:tournament_management/pages/participation/participation_list_page.dart';

class ParticipationPresenter {
  final ParticipationViewModel viewModel;
  ParticipationPresenter(this.viewModel);

  Widget buildMyCalendar(BuildContext context) {
  return FutureBuilder<List<ParticipationModel>>(
    future: viewModel.fetchCalendarFromFirebase(false), // false = à jouer
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('error_fetching'.tr()));
      }
      final data = snapshot.data ?? const <ParticipationModel>[];
      if (data.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(child: Text('no_calendar_data'.tr())),
        );
      }
      return _buildList(_sorted(data, played: false), context, played: false);
    },
  );
}

Widget buildMyResult(BuildContext context) {
  return FutureBuilder<List<ParticipationModel>>(
    future: viewModel.fetchCalendarFromFirebase(true), // true = joués
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('error_fetching'.tr()));
      }
      final data = snapshot.data ?? const <ParticipationModel>[];
      if (data.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(child: Text('no_result'.tr())),
        );
      }
      return _buildList(_sorted(data, played: true), context, played: true);
    },
  );
}

Widget _buildList(List<ParticipationModel> list, BuildContext context, {required bool played}) {
  // Limite à 3 (comme ton code), mais après tri
  final data = list;
  final count = data.length < 3 ? data.length : 3;
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: count,
    itemBuilder: (context, index) => _buildItem(data, index, context),
  );
}

  Widget _buildItem(List<ParticipationModel> list, int index, BuildContext context) {
    final item = list[index];
    final opname = item.opposant;
    final date = item.date;
    final location = item.location;
    final score = item.score;

    // Si ta date contient "→ ", on n’affiche que la partie gauche comme tu faisais
    final displayDate = date.contains('→ ') ? date.split('→ ').first : date;

    return Column(
      children: [
        const SizedBox(height: 10),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 10),

        Text('opponent').tr(args: [opname]),
        Text('match_date').tr(args: [displayDate]),
        Text('location').tr(args: [location]),
        if (score.isNotEmpty) Text('score').tr(args: [score]),
      ],
    );
  }
  
  
  
  List<ParticipationModel> _sorted(List<ParticipationModel> list, {required bool played}) {
  final copy = List<ParticipationModel>.from(list);
  copy.sort((a, b) {
    final da = _parseDate(a.date);
    final db = _parseDate(b.date);
    // à jouer: dates les plus proches d’abord ; résultats: plus récents d’abord
    return played ? db.compareTo(da) : da.compareTo(db);
  });
  return copy;
}


  Future<List<ParticipationModel>> load({required bool played}) {
    return viewModel.fetchCalendarFromFirebase(played);
  }


  List<ParticipationModel> sorted(List<ParticipationModel> list, {required bool played}) {
    final copy = List<ParticipationModel>.from(list);
    copy.sort((a, b) {
      final da = _parseDate(a.date);
      final db = _parseDate(b.date);
      return played ? db.compareTo(da) : da.compareTo(db); // joués -> récents d'abord
    });
    return copy;
  }

  DateTime _parseDate(String raw) {
    final s = raw.contains('→ ') ? raw.split('→ ').first : raw;
    try { return DateTime.parse(s.split(' ').first); } catch (_) {}
    try {
      final parts = s.split(RegExp(r'[/\-.]'));
      if (parts.length >= 3) {
        final d = int.parse(parts[0]), m = int.parse(parts[1]), y = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }


  void openFullList(BuildContext context, {required bool played}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParticipationListPage(played: played),
    ));
  }


}
