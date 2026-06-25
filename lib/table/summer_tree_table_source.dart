import 'summer_data_table_source.dart';

/// A [SummerDataTableSource] that exposes hierarchical (tree) rows.
///
/// The source owns the visible-row flattening and the expand/collapse state:
/// * [rowCount] reflects the number of currently visible nodes (expanded
///   branches are flattened in).
/// * [rowDepth] / [rowHasChildren] / [rowExpanded] describe the tree shape at
///   a visible index.
/// * [toggleExpanded] flips a node and must call [notifyListeners].
///
/// When the table detects that its source is a [SummerTreeTableSource] it
/// renders depth indentation and an expand caret in the first user column.
abstract class SummerTreeTableSource extends SummerDataTableSource {
  /// Depth of the visible row at [rowIndex] (0 = top level).
  int rowDepth(int rowIndex);

  /// Whether the visible row at [rowIndex] has children (shows a caret).
  bool rowHasChildren(int rowIndex);

  /// Whether the visible row at [rowIndex] is currently expanded.
  bool rowExpanded(int rowIndex);

  /// Expand or collapse the visible row at [rowIndex]; must notify listeners.
  void toggleExpanded(int rowIndex);
}
