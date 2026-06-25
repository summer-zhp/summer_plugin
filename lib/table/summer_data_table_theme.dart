import 'package:flutter/material.dart';

/// Theme data for [SummerDataTable].
class SummerDataTableThemeData {
  /// Background color of the header row.
  final Color headerBackgroundColor;

  /// Text style for header cells.
  final TextStyle headerTextStyle;

  /// Default background color for data rows.
  final Color cellBackgroundColor;

  /// Background color for alternating (odd) rows. Null disables striping.
  final Color? altRowBackgroundColor;

  /// Background color applied while hovering a row (null disables hover).
  final Color? hoverColor;

  /// Background color applied to selected rows.
  final Color? selectedColor;

  /// Text color (and sort icon color) of the active sort column header.
  final Color sortActiveColor;

  /// Default text style for data cells.
  final TextStyle cellTextStyle;

  /// Default height for data rows.
  final double rowHeight;

  /// Height of the header row.
  final double headerHeight;

  /// Border color for outer and inner borders.
  final Color borderColor;

  /// Border width.
  final double borderWidth;

  /// Color of the column-resize drag handle.
  final Color resizeHandleColor;

  /// Hit width of the column-resize drag handle.
  final double resizeHandleWidth;

  /// Icon displayed when a column is sorted ascending.
  final Widget sortAscendingIcon;

  /// Icon displayed when a column is sorted descending.
  final Widget sortDescendingIcon;

  /// Expand / collapse chevron for expandable rows.
  final Widget expandIcon;

  /// Widget shown during loading state.
  final Widget? loadingWidget;

  /// Widget shown when data is empty.
  final Widget? emptyWidget;

  const SummerDataTableThemeData({
    required this.headerBackgroundColor,
    required this.headerTextStyle,
    required this.cellBackgroundColor,
    required this.altRowBackgroundColor,
    required this.hoverColor,
    required this.selectedColor,
    required this.sortActiveColor,
    required this.cellTextStyle,
    required this.rowHeight,
    required this.headerHeight,
    required this.borderColor,
    required this.borderWidth,
    required this.resizeHandleColor,
    required this.resizeHandleWidth,
    required this.sortAscendingIcon,
    required this.sortDescendingIcon,
    required this.expandIcon,
    this.loadingWidget,
    this.emptyWidget,
  });

  /// Returns a sensible default theme (antd-like).
  factory SummerDataTableThemeData.defaultTheme() {
    const primary = Color(0xFF1890FF);
    return SummerDataTableThemeData(
      headerBackgroundColor: const Color(0xFFFAFAFA),
      headerTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
      ),
      cellBackgroundColor: const Color(0xFFFFFFFF),
      altRowBackgroundColor: const Color(0xFFFAFAFA),
      hoverColor: const Color(0xFFF5F5F5),
      selectedColor: const Color(0xFFE6F7FF),
      sortActiveColor: primary,
      cellTextStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF333333),
      ),
      rowHeight: 48.0,
      headerHeight: 48.0,
      borderColor: const Color(0xFFF0F0F0),
      borderWidth: 1.0,
      resizeHandleColor: const Color(0xFFD9D9D9),
      resizeHandleWidth: 6.0,
      sortAscendingIcon: const _SortIcon(ascending: true),
      sortDescendingIcon: const _SortIcon(ascending: false),
      expandIcon: const Icon(Icons.keyboard_arrow_right,
          size: 20, color: Color(0xFF999999)),
    );
  }

  /// Creates a copy with optional overrides.
  SummerDataTableThemeData copyWith({
    Color? headerBackgroundColor,
    TextStyle? headerTextStyle,
    Color? cellBackgroundColor,
    Color? altRowBackgroundColor,
    Color? hoverColor,
    Color? selectedColor,
    Color? sortActiveColor,
    TextStyle? cellTextStyle,
    double? rowHeight,
    double? headerHeight,
    Color? borderColor,
    double? borderWidth,
    Color? resizeHandleColor,
    double? resizeHandleWidth,
    Widget? sortAscendingIcon,
    Widget? sortDescendingIcon,
    Widget? expandIcon,
    Widget? loadingWidget,
    Widget? emptyWidget,
  }) {
    return SummerDataTableThemeData(
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      cellBackgroundColor: cellBackgroundColor ?? this.cellBackgroundColor,
      altRowBackgroundColor:
          altRowBackgroundColor ?? this.altRowBackgroundColor,
      hoverColor: hoverColor ?? this.hoverColor,
      selectedColor: selectedColor ?? this.selectedColor,
      sortActiveColor: sortActiveColor ?? this.sortActiveColor,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      rowHeight: rowHeight ?? this.rowHeight,
      headerHeight: headerHeight ?? this.headerHeight,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      resizeHandleColor: resizeHandleColor ?? this.resizeHandleColor,
      resizeHandleWidth: resizeHandleWidth ?? this.resizeHandleWidth,
      sortAscendingIcon: sortAscendingIcon ?? this.sortAscendingIcon,
      sortDescendingIcon: sortDescendingIcon ?? this.sortDescendingIcon,
      expandIcon: expandIcon ?? this.expandIcon,
      loadingWidget: loadingWidget ?? this.loadingWidget,
      emptyWidget: emptyWidget ?? this.emptyWidget,
    );
  }
}

/// InheritedWidget that provides [SummerDataTableThemeData] to descendants.
class SummerDataTableTheme extends InheritedWidget {
  final SummerDataTableThemeData data;

  const SummerDataTableTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static SummerDataTableThemeData of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SummerDataTableTheme>()
            ?.data ??
        SummerDataTableThemeData.defaultTheme();
  }

  @override
  bool updateShouldNotify(SummerDataTableTheme oldWidget) =>
      data != oldWidget.data;
}

/// Default caret-style sort indicator (▲ / ▼).
class _SortIcon extends StatelessWidget {
  final bool ascending;
  const _SortIcon({required this.ascending});

  @override
  Widget build(BuildContext context) {
    return Text(
      ascending ? '▲' : '▼',
      style: const TextStyle(fontSize: 10, color: Color(0xFF1890FF)),
    );
  }
}
