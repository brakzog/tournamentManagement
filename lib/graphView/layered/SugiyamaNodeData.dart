// ignore: file_names, use_string_in_part_of_directives
// ignore_for_file: file_names, duplicate_ignore, use_string_in_part_of_directives
part of graphview;

class SugiyamaNodeData {
  Set<Node> reversed = {};
  bool isDummy = false;
  int median = -1;
  int layer = -1;
  int position = -1;
  List<Node> predecessorNodes = [];
  List<Node> successorNodes = [];

  bool get isReversed => reversed.isNotEmpty;

  @override
  String toString() {
    return 'SugiyamaNodeData{reversed: $reversed, isDummy: $isDummy, median: $median, layer: $layer, position: $position';
  }
}
