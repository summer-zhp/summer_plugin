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

/// A single active sort entry (used for multi-column sort).
class SummerSortSpec {
  /// Column key being sorted.
  final String key;

  /// Sort direction: `true` = ascending, `false` = descending.
  final bool ascending;

  const SummerSortSpec({required this.key, this.ascending = true});

  @override
  bool operator ==(Object other) =>
      other is SummerSortSpec && other.key == key && other.ascending == ascending;

  @override
  int get hashCode => Object.hash(key, ascending);

  @override
  String toString() => 'SummerSortSpec($key, ${ascending ? 'asc' : 'desc'})';
}

/// A selectable option in a column filter dropdown.
class SummerColumnFilter {
  /// Value reported via [SummerDataTable.filteredColumnValues].
  final Object? value;

  /// Display label.
  final String text;

  const SummerColumnFilter({required this.value, required this.text});
}

/// Defines a column in [SummerDataTable].
///
/// Width resolution rules:
/// * [width] provided → fixed-size, participates in horizontal scrolling.
/// * Otherwise → elastic, shares remaining viewport space by [flex].
class SummerDataColumn {
  /// Header content (usually a [Text]).
  final Widget label;

  /// Stable identifier. Used for sort, resize and filter keys.
  final String? key;

  /// Fixed width in logical pixels. `null` → flex-sized.
  final double? width;

  /// Flex weight for elastic columns. Ignored when [width] is set.
  final int flex;

  /// Minimum width.
  final double minWidth;

  /// Maximum width.
  final double maxWidth;

  /// Whether the header is tappable to sort.
  final bool sortable;

  /// Permitted sort directions in click order, as a list where `true` = ascend
  /// and `false` = descend. Default `[true, false]` (asc → desc → unsort).
  /// Append nothing extra; a third click always returns to "unsorted".
  final List<bool> sortDirections;

  /// Whether the user can drag the column's right border to resize it.
  final bool resizable;

  /// When true, overflowing cell text is ellipsized and a tooltip is shown.
  final bool ellipsis;

  /// Default content alignment for cells and the header.
  final AlignmentGeometry alignment;

  /// Inner padding applied to header and body cells of this column.
  final EdgeInsetsGeometry padding;

  /// Whether the column is frozen to a viewport edge.
  final SummerColumnPin pin;

  /// Optional tooltip for the header cell.
  final String? headerTooltip;

  /// Filter options for the header dropdown. `null` disables filtering.
  final List<SummerColumnFilter>? filters;

  /// Whether the filter dropdown allows multiple selections.
  final bool filterMultiple;

  /// Child columns. When non-empty this column becomes a **header-only group**
  /// (antd/naive-style column grouping): its [label] spans all descendant
  /// columns in a merged header row, and body cells are rendered only for the
  /// (recursively) leaf columns beneath it.
  ///
  /// Groups are display-only — sorting/resizing/filtering/pinning are ignored
  /// on a group and apply only to its leaves. Only top-level columns may be
  /// pinned ([SummerColumnPin]); a column nested inside a group is always
  /// treated as part of the horizontally-scrollable middle band.
  final List<SummerDataColumn> children;

  /// Whether this column is a header group (has [children]).
  bool get isGroup => children.isNotEmpty;

  const SummerDataColumn({
    required this.label,
    this.key,
    this.width,
    this.flex = 1,
    this.minWidth = 40.0,
    this.maxWidth = double.infinity,
    this.sortable = false,
    this.sortDirections = const [true, false],
    this.resizable = false,
    this.ellipsis = false,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.pin = SummerColumnPin.none,
    this.headerTooltip,
    this.filters,
    this.filterMultiple = true,
    this.children = const [],
  });

  /// Whether this column has a user-defined fixed width.
  bool get isFixed => width != null;
}

/// A node in a hierarchical (tree) table.
class SummerTreeNode {
  /// Stable identity (combined with ancestors for uniqueness).
  final Object? key;

  /// Child nodes.
  final List<SummerTreeNode> children;

  const SummerTreeNode({this.key, this.children = const []});
}
