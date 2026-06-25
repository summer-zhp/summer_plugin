import 'package:flutter/widgets.dart';

/// Expandable-row configuration (controlled).
///
/// The caller owns [expandedKeys] and updates them in [onChanged].
class SummerRowExpandable {
  /// Row keys currently expanded.
  final Set<Object?> expandedKeys;

  /// Builds the expansion panel shown beneath the expanded row.
  final Widget Function(BuildContext context, int rowIndex) builder;

  /// Invoked with the new key set when expansion toggles.
  final ValueChanged<Set<Object?>>? onChanged;

  /// Icon shown when the row is collapsed.
  final Widget? expandIcon;

  /// Icon shown when the row is expanded.
  final Widget? collapseIcon;

  /// Width of the leading expand-toggle column.
  final double columnWidth;

  const SummerRowExpandable({
    required this.expandedKeys,
    required this.builder,
    this.onChanged,
    this.expandIcon,
    this.collapseIcon,
    this.columnWidth = 40.0,
  });
}
