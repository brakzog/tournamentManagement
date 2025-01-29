import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tournament_management/models/match.dart';
import 'package:tournament_management/models/tournament.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament_presenter.dart';
import 'package:tournament_management/pages/detail_tournament/detail_tournament_viewmodel.dart';

import 'detailtournament_presenter_test.mocks.dart';

@GenerateMocks([Tournament, DetailTournamentViewModel])
void main() {
  group('TournamentPresenter - calculateWins', () {
    late DetailTournamentPresenter presenter;
    late MockTournament mockTournament;
    late MockDetailTournamentViewModel mockViewModel;


    setUp(() {
      mockTournament = MockTournament();
      mockViewModel = MockDetailTournamentViewModel();

      presenter = DetailTournamentPresenter(
        mockTournament,
        () => true, // Une fonction fictive
        false, // Une valeur fictive
        mockViewModel,
      );
    });

    test('should calculate wins correctly for matches', () {
      final matches = [
        MatchTournament(player1: 'Alice', player2: 'Bob', score: '6-4;3-6;7-5'),
        MatchTournament(player1: 'Alice', player2: 'Charlie', score: '6-2;6-3'),
        MatchTournament(player1: 'Bob', player2: 'Charlie', score: '6-7;7-6;7-5'),
      ];

      final players = ['Alice', 'Bob', 'Charlie'];
      final wins = presenter.calculateWins(matches, players);

      expect(wins['Alice'], 2);
      expect(wins['Bob'], 1);
      expect(wins['Charlie'], 0);
    });
  });
}