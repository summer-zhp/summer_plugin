import 'package:flutter/widgets.dart';

/// Where a column is pinned relative to the viewport.
enum SummerColumnPin {
  /// Scrolls normally with the content.
  none,

  /// Frozen on the left edge, never scrolls horizontally.
  left,

  /// Frozen on the right edge, never scrolls horizontally.
  right,
}

/// Defines a column in [SummerDataTable].
///
/// Width resolution rules (mirrors antd / naive DataTable):
/// * If [width] is provided the column is fixed-size and participates in
///   horizontal scrolling once the total fixed width exceeds the viewport.
/// * Otherwise the column is elastic and shares the remaining viewport space
///   proportionally to [flex]. Elastic columns never trigger horizontal scroll
///   on their own.
class SummerDataColumn {
  /// Header content (usually a [Text]).
  final Widget label;

  /// Stable identifier. Used as the resize key and for sort/change reporting.
  /// Defaults to the column index.
  final String? key;

  /// Fixed width in logical pixels. When `null` the column is flex-sized.
  final double? width;

  /// Flex weight for elastic (non-fixed) columns. Ignored when [width] is set.
  final int flex;

  /// Minimum width. Fixed columns clamp to this; elastic columns never shrink
  /// below it.
  final double minWidth;

  /// Maximum width. Fixed columns clamp to this.
  final double maxWidth;

  /// Whether tapping the header cycles sort order for this column.
  final bool sortable;

  /// Whether the user can drag the column's right border to resize it.
  final bool resizable;

  /// When true, overflowing cell text is ellipsized and a tooltip is shown.
  final bool ellipsis;

  /// Default content alignment for cells and the header in this column.
  final AlignmentGeometry alignment;

  /// Inner padding applied to header and body cells of this column.
  final EdgeInsetsGeometry padding;

  /// Whether the column is frozen to a viewport edge.
  final SummerColumnPin pin;

  /// Optional tooltip for the header cell.
  final String? headerTooltip;

  const SummerDataColumn({
    required this.label,
    this.key,
    this.width,
    this.flex = 1,
    this.minWidth = 40.0,
    this.maxWidth = double.infinity,
    this.sortable = false,
    this.resizable = false,
    this.ellipsis = false,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.pin = SummerColumnPin.none,
    this.headerTooltip,
  });

  /// Whether this column has a user-defined fixed width.
  bool get isFixed => width != null;
}
