import 'package:flutter/material.dart';

import '../graphView/GraphView.dart';
import '../models/match.dart';

class TournamentNode extends Node {
  final String label;

  /// Le match auquel appartient ce joueur, si applicable.
  /// Null pour un nœud purement informatif (ex: le nœud "Winner" en tête
  /// d'arbre), qui ne représente pas un match jouable.
  final MatchTournament? match;

  TournamentNode(int super.id, this.label, {this.match}) : super.Id();

  static Widget builder(BuildContext context, Node node, Map<int, Node> graph) {
    return Builder(
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue, // Couleur du nœud
          ),
          child: Center(
            child: Text(
              (node as TournamentNode).label,
              style: const TextStyle(color: Colors.white), // Couleur du texte
            ),
          ),
        );
      },
    );
  }
}
