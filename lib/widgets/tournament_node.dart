import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class TournamentNode extends Node {
  final String label;

  TournamentNode(int super.id, this.label) : super.Id();

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
