// ignore: file_names, use_string_in_part_of_directives
// ignore_for_file: file_names, duplicate_ignore, use_string_in_part_of_directives

part of graphview;

abstract class Algorithm {
  EdgeRenderer? renderer;

  /// Executes the algorithm.
  /// @param shiftY Shifts the y-coordinate origin
  /// @param shiftX Shifts the x-coordinate origin
  /// @return The size of the graph
  Size run(Graph? graph, double shiftX, double shiftY);

  void setFocusedNode(Node node);

  void init(Graph? graph);

  void step(Graph? graph);

  void setDimensions(double width, double height);
}
