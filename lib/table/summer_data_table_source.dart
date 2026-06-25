import 'package:flutter/widgets.dart';

/// Data source for [SummerDataTable].
///
/// Replaces the old imperative delegate. Extend [ChangeNotifier] and call
/// [notifyListeners] whenever the row data changes so the table rebuilds.
abstract class SummerDataTableSource extends ChangeNotifier {
  /// Total number of data rows currently held by this source.
  int get rowCount;

  /// Build the cell widget for [rowIndex] x [columnIndex].
  ///
  /// [columnIndex] is the index among the user-defined columns (selection and
  /// expand helper columns are excluded).
  Widget buildCell(BuildContext context, int rowIndex, int columnIndex);

  /// Stable identity for [rowIndex], used by selection and expansion.
  /// Defaults to the row index.
  Object? rowKey(int rowIndex) => rowIndex;
}
